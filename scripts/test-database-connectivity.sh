#!/bin/bash

# 데이터베이스 연결 테스트 전용 스크립트

set -e

# 환경 변수 설정
CLUSTER_NAME=${1:-"goorm-popcorn-dev-cluster"}
REGION=${2:-"ap-northeast-2"}
ENVIRONMENT=${3:-"dev"}

echo "=== 데이터베이스 연결 테스트 ==="
echo "클러스터: $CLUSTER_NAME"
echo "리전: $REGION"
echo "환경: $ENVIRONMENT"
echo

# 1. RDS 상세 정보 확인
echo "1. RDS PostgreSQL 상세 정보"
echo "================================"

RDS_INFO=$(aws rds describe-db-instances --region $REGION \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'popcorn') && contains(DBInstanceIdentifier, '$ENVIRONMENT')].{
    Identifier:DBInstanceIdentifier,
    Status:DBInstanceStatus,
    Engine:Engine,
    Version:EngineVersion,
    Endpoint:Endpoint.Address,
    Port:Endpoint.Port,
    MultiAZ:MultiAZ,
    StorageEncrypted:StorageEncrypted,
    VpcId:DBSubnetGroup.VpcId
  }" --output table)

echo "$RDS_INFO"

RDS_ENDPOINT=$(aws rds describe-db-instances --region $REGION \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'popcorn') && contains(DBInstanceIdentifier, '$ENVIRONMENT')].Endpoint.Address" \
  --output text | head -1)

echo "RDS 엔드포인트: $RDS_ENDPOINT"
echo

# 2. ElastiCache (Valkey) 상세 정보 확인
echo "2. ElastiCache (Valkey) 상세 정보"
echo "=================================="

# 단일 노드 클러스터 확인
CACHE_INFO=$(aws elasticache describe-cache-clusters --region $REGION --show-cache-node-info \
  --query "CacheClusters[?contains(CacheClusterId, 'popcorn') && contains(CacheClusterId, '$ENVIRONMENT')].{
    ClusterId:CacheClusterId,
    Status:CacheClusterStatus,
    Engine:Engine,
    Version:EngineVersion,
    NodeType:CacheNodeType,
    Endpoint:CacheNodes[0].Endpoint.Address,
    Port:CacheNodes[0].Endpoint.Port
  }" --output table 2>/dev/null)

if [ ! -z "$CACHE_INFO" ] && [ "$CACHE_INFO" != "[]" ]; then
    echo "$CACHE_INFO"
    REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters --region $REGION --show-cache-node-info \
      --query "CacheClusters[?contains(CacheClusterId, 'popcorn') && contains(CacheClusterId, '$ENVIRONMENT')].CacheNodes[0].Endpoint.Address" \
      --output text | head -1)
else
    # Replication Group 확인 (클러스터 모드 또는 복제본)
    REPL_INFO=$(aws elasticache describe-replication-groups --region $REGION \
      --query "ReplicationGroups[?contains(ReplicationGroupId, 'popcorn') && contains(ReplicationGroupId, '$ENVIRONMENT')].{
        GroupId:ReplicationGroupId,
        Status:Status,
        Engine:CacheNodeType,
        PrimaryEndpoint:NodeGroups[0].PrimaryEndpoint.Address,
        Port:NodeGroups[0].PrimaryEndpoint.Port,
        NumNodes:NumCacheClusters
      }" --output table 2>/dev/null)
    
    echo "$REPL_INFO"
    REDIS_ENDPOINT=$(aws elasticache describe-replication-groups --region $REGION \
      --query "ReplicationGroups[?contains(ReplicationGroupId, 'popcorn') && contains(ReplicationGroupId, '$ENVIRONMENT')].NodeGroups[0].PrimaryEndpoint.Address" \
      --output text | head -1)
fi

echo "Valkey/Redis 엔드포인트: $REDIS_ENDPOINT"
echo

# 3. 보안 그룹 분석
echo "3. 데이터베이스 보안 그룹 분석"
echo "=============================="

if [ ! -z "$RDS_ENDPOINT" ]; then
    # RDS 보안 그룹 확인
    RDS_SG=$(aws rds describe-db-instances --region $REGION \
      --query "DBInstances[?Endpoint.Address=='$RDS_ENDPOINT'].VpcSecurityGroups[0].VpcSecurityGroupId" \
      --output text)
    
    echo "RDS 보안 그룹: $RDS_SG"
    if [ ! -z "$RDS_SG" ] && [ "$RDS_SG" != "None" ]; then
        aws ec2 describe-security-groups --group-ids $RDS_SG --region $REGION \
          --query 'SecurityGroups[0].IpPermissions[].{Protocol:IpProtocol,Port:FromPort,Source:IpRanges[0].CidrIp,SourceSG:UserIdGroupPairs[0].GroupId}' \
          --output table
    fi
    echo
fi

if [ ! -z "$REDIS_ENDPOINT" ]; then
    # ElastiCache 보안 그룹은 서브넷 그룹을 통해 확인
    echo "ElastiCache 서브넷 그룹 정보:"
    aws elasticache describe-cache-subnet-groups --region $REGION \
      --query "CacheSubnetGroups[?contains(CacheSubnetGroupName, 'popcorn')].{
        Name:CacheSubnetGroupName,
        VpcId:VpcId,
        Subnets:Subnets[].SubnetId
      }" --output table
    echo
fi

# 4. ECS 태스크에서 실제 연결 테스트
echo "4. ECS 태스크에서 연결 테스트 실행"
echo "=================================="

# 실행 중인 태스크 찾기
TASKS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --region $REGION --query 'taskArns[]' --output text)
FIRST_TASK=$(echo $TASKS | awk '{print $1}')

if [ ! -z "$FIRST_TASK" ]; then
    TASK_ID=$(basename $FIRST_TASK)
    CONTAINER_NAME=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $FIRST_TASK --region $REGION \
      --query 'tasks[0].containers[0].name' --output text)
    
    echo "테스트 태스크: $TASK_ID"
    echo "컨테이너: $CONTAINER_NAME"
    echo

    # 네트워크 도구 설치 및 테스트 스크립트 생성
    TEST_SCRIPT="/tmp/db_test.sh"
    
    cat > /tmp/local_db_test.sh << 'EOF'
#!/bin/bash
echo "=== 컨테이너 내부 연결 테스트 ==="

# 필요한 도구 설치 확인
echo "1. 네트워크 도구 확인"
which nc || echo "netcat 없음"
which telnet || echo "telnet 없음"
which psql || echo "postgresql-client 없음"
which redis-cli || echo "redis-cli 없음"
echo

# RDS 연결 테스트
if [ ! -z "$1" ]; then
    echo "2. RDS PostgreSQL 연결 테스트"
    echo "엔드포인트: $1"
    
    # 포트 연결 테스트
    if which nc > /dev/null; then
        echo "nc 테스트:"
        timeout 5 nc -zv $1 5432 && echo "✅ RDS 포트 연결 성공" || echo "❌ RDS 포트 연결 실패"
    fi
    
    if which telnet > /dev/null; then
        echo "telnet 테스트:"
        timeout 5 bash -c "echo quit | telnet $1 5432" && echo "✅ RDS telnet 연결 성공" || echo "❌ RDS telnet 연결 실패"
    fi
    
    # PostgreSQL 클라이언트 테스트
    if which psql > /dev/null; then
        echo "PostgreSQL 클라이언트 테스트:"
        PGPASSWORD=${DB_PASSWORD:-1234} timeout 10 psql -h $1 -U ${DB_USERNAME:-postgres} -d ${DB_NAME:-popcorn_db} -c "SELECT version();" \
          && echo "✅ PostgreSQL 연결 및 쿼리 성공" || echo "❌ PostgreSQL 연결 실패"
    fi
    echo
fi

# Redis 연결 테스트
if [ ! -z "$2" ]; then
    echo "3. Valkey/Redis 연결 테스트"
    echo "엔드포인트: $2"
    
    # 포트 연결 테스트
    if which nc > /dev/null; then
        echo "nc 테스트:"
        timeout 5 nc -zv $2 6379 && echo "✅ Redis 포트 연결 성공" || echo "❌ Redis 포트 연결 실패"
    fi
    
    if which telnet > /dev/null; then
        echo "telnet 테스트:"
        timeout 5 bash -c "echo quit | telnet $2 6379" && echo "✅ Redis telnet 연결 성공" || echo "❌ Redis telnet 연결 실패"
    fi
    
    # Redis 클라이언트 테스트
    if which redis-cli > /dev/null; then
        echo "Redis 클라이언트 테스트:"
        timeout 10 redis-cli -h $2 ping && echo "✅ Redis PING 성공" || echo "❌ Redis PING 실패"
        timeout 10 redis-cli -h $2 info server | head -5 && echo "✅ Redis INFO 성공" || echo "❌ Redis INFO 실패"
    fi
    echo
fi

echo "4. 환경 변수 확인"
echo "DB_HOST: ${DB_HOST:-'설정되지 않음'}"
echo "DB_NAME: ${DB_NAME:-'설정되지 않음'}"
echo "DB_USERNAME: ${DB_USERNAME:-'설정되지 않음'}"
echo "REDIS_HOST: ${REDIS_HOST:-'설정되지 않음'}"
echo

echo "=== 테스트 완료 ==="
EOF

    # 스크립트를 컨테이너에 복사하고 실행
    echo "컨테이너에서 연결 테스트 실행 중..."
    
    # ECS Exec이 활성화되어 있는지 확인
    EXEC_ENABLED=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $FIRST_TASK --region $REGION \
      --query 'tasks[0].enableExecuteCommand' --output text)
    
    if [ "$EXEC_ENABLED" = "true" ]; then
        echo "ECS Exec이 활성화되어 있습니다. 테스트를 실행합니다..."
        
        # 스크립트 내용을 직접 실행
        aws ecs execute-command \
          --cluster $CLUSTER_NAME \
          --task $FIRST_TASK \
          --container $CONTAINER_NAME \
          --interactive \
          --command "bash -c '
            echo \"=== 컨테이너 내부 연결 테스트 ===\"
            echo \"1. 네트워크 도구 확인\"
            which nc || echo \"netcat 없음\"
            which telnet || echo \"telnet 없음\"
            which psql || echo \"postgresql-client 없음\"
            which redis-cli || echo \"redis-cli 없음\"
            echo
            
            if [ ! -z \"$RDS_ENDPOINT\" ]; then
                echo \"2. RDS PostgreSQL 연결 테스트 ($RDS_ENDPOINT)\"
                timeout 5 nc -zv $RDS_ENDPOINT 5432 && echo \"✅ RDS 포트 연결 성공\" || echo \"❌ RDS 포트 연결 실패\"
                echo
            fi
            
            if [ ! -z \"$REDIS_ENDPOINT\" ]; then
                echo \"3. Valkey/Redis 연결 테스트 ($REDIS_ENDPOINT)\"
                timeout 5 nc -zv $REDIS_ENDPOINT 6379 && echo \"✅ Redis 포트 연결 성공\" || echo \"❌ Redis 포트 연결 실패\"
                echo
            fi
            
            echo \"4. 환경 변수 확인\"
            echo \"DB_HOST: \${DB_HOST:-설정되지 않음}\"
            echo \"REDIS_HOST: \${REDIS_HOST:-설정되지 않음}\"
          '" \
          --region $REGION || echo "❌ ECS Exec 실행 실패"
    else
        echo "❌ ECS Exec이 비활성화되어 있습니다."
        echo "ECS Exec을 활성화하려면 태스크 정의에서 enableExecuteCommand를 true로 설정하세요."
    fi
else
    echo "❌ 실행 중인 태스크가 없습니다."
fi

echo

# 5. CloudWatch 로그에서 연결 오류 확인
echo "5. CloudWatch 로그에서 데이터베이스 연결 오류 확인"
echo "=============================================="

LOG_GROUPS=$(aws logs describe-log-groups --region $REGION \
  --log-group-name-prefix "/aws/ecs/goorm-popcorn-$ENVIRONMENT" \
  --query 'logGroups[].logGroupName' --output text)

for log_group in $LOG_GROUPS; do
    echo "로그 그룹: $log_group"
    
    # 데이터베이스 관련 오류 검색
    echo "  데이터베이스 연결 오류:"
    aws logs filter-log-events --log-group-name $log_group --region $REGION \
      --start-time $(date -d '1 hour ago' +%s)000 \
      --filter-pattern '{ $.level = "ERROR" && ($.message = "*database*" || $.message = "*connection*" || $.message = "*redis*" || $.message = "*postgres*") }' \
      --query 'events[].message' --output text | head -3 || echo "    오류 없음"
    
    echo "  최근 연결 관련 로그:"
    aws logs filter-log-events --log-group-name $log_group --region $REGION \
      --start-time $(date -d '10 minutes ago' +%s)000 \
      --filter-pattern '"connect"' \
      --query 'events[].message' --output text | head -2 || echo "    로그 없음"
    echo
done

# 6. 연결 문제 해결 가이드
echo "6. 연결 문제 해결 가이드"
echo "======================"
echo
echo "연결 실패 시 확인사항:"
echo
echo "1. 보안 그룹 규칙 확인:"
echo "   - ECS 태스크의 보안 그룹에서 RDS/ElastiCache로의 아웃바운드 허용"
echo "   - RDS/ElastiCache 보안 그룹에서 ECS 보안 그룹으로부터의 인바운드 허용"
echo
echo "2. 서브넷 라우팅 확인:"
echo "   - ECS 태스크와 데이터베이스가 같은 VPC에 있는지 확인"
echo "   - 프라이빗 서브넷 간 라우팅 테이블 확인"
echo
echo "3. DNS 해석 확인:"
echo "   - VPC DNS 해석 활성화 확인"
echo "   - 엔드포인트 주소가 올바른지 확인"
echo
echo "4. 애플리케이션 설정 확인:"
echo "   - 환경 변수 (DB_HOST, REDIS_HOST) 설정"
echo "   - 연결 풀 설정 및 타임아웃 설정"
echo
echo "5. 네트워크 ACL 확인:"
echo "   - 서브넷 레벨의 네트워크 ACL 규칙"
echo

echo "=== 데이터베이스 연결 테스트 완료 ==="