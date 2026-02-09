#!/bin/bash

# ECS 컨테이너 간 통신 테스트 스크립트

set -e

# 환경 변수 설정
CLUSTER_NAME=${1:-"goorm-popcorn-dev-cluster"}
REGION=${2:-"ap-northeast-2"}

echo "=== ECS 컨테이너 간 통신 테스트 ==="
echo "클러스터: $CLUSTER_NAME"
echo "리전: $REGION"
echo

# 1. 클러스터 상태 확인
echo "1. 클러스터 상태 확인"
aws ecs describe-clusters --clusters $CLUSTER_NAME --region $REGION \
  --query 'clusters[0].{Status:status,ActiveServices:activeServicesCount,RunningTasks:runningTasksCount}'

echo

# 2. 실행 중인 서비스 목록
echo "2. 실행 중인 서비스 목록"
SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --region $REGION --query 'serviceArns[]' --output text)

for service_arn in $SERVICES; do
    service_name=$(basename $service_arn)
    echo "- $service_name"
    
    # 서비스 상태 확인
    aws ecs describe-services --cluster $CLUSTER_NAME --services $service_arn --region $REGION \
      --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount,Status:status}' \
      --output table
done

echo

# 3. 태스크 목록 및 IP 확인
echo "3. 실행 중인 태스크 및 IP 주소"
TASKS=$(aws ecs list-tasks --cluster $CLUSTER_NAME --region $REGION --query 'taskArns[]' --output text)

for task_arn in $TASKS; do
    task_id=$(basename $task_arn)
    echo "태스크 ID: $task_id"
    
    # 태스크 세부 정보
    aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $task_arn --region $REGION \
      --query 'tasks[0].{LastStatus:lastStatus,HealthStatus:healthStatus,Group:group}' \
      --output table
    
    # ENI 정보 확인
    ENI_ID=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $task_arn --region $REGION \
      --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
    
    if [ ! -z "$ENI_ID" ]; then
        PRIVATE_IP=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --region $REGION \
          --query 'NetworkInterfaces[0].PrivateIpAddress' --output text)
        echo "Private IP: $PRIVATE_IP"
    fi
    
    echo "---"
done

echo

# 4. CloudMap 서비스 디스커버리 확인
echo "4. CloudMap 서비스 디스커버리 확인"
NAMESPACES=$(aws servicediscovery list-namespaces --region $REGION --query 'Namespaces[?Type==`DNS_PRIVATE`].{Name:Name,Id:Id}' --output table)
echo "$NAMESPACES"

echo

# 5. 보안 그룹 규칙 확인
echo "5. ECS 보안 그룹 규칙 확인"
SG_IDS=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICES --region $REGION \
  --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[]' --output text)

for sg_id in $SG_IDS; do
    echo "보안 그룹: $sg_id"
    aws ec2 describe-security-groups --group-ids $sg_id --region $REGION \
      --query 'SecurityGroups[0].{GroupName:GroupName,InboundRules:IpPermissions[].{Protocol:IpProtocol,Port:FromPort,Source:IpRanges[0].CidrIp}}' \
      --output table
    echo "---"
done

# 6. RDS 연결 테스트
echo "6. RDS PostgreSQL 연결 테스트"
RDS_INSTANCES=$(aws rds describe-db-instances --region $REGION \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `popcorn`)].{Identifier:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address,Port:Endpoint.Port}' \
  --output table)
echo "$RDS_INSTANCES"

# RDS 엔드포인트 정보
RDS_ENDPOINT=$(aws rds describe-db-instances --region $REGION \
  --query 'DBInstances[?contains(DBInstanceIdentifier, `popcorn`)].Endpoint.Address' --output text | head -1)

if [ ! -z "$RDS_ENDPOINT" ]; then
    echo "RDS 엔드포인트: $RDS_ENDPOINT"
    
    # 포트 연결 테스트 (ECS 컨테이너에서 실행할 명령어 예시)
    echo "ECS 컨테이너에서 RDS 연결 테스트 명령어:"
    echo "  telnet $RDS_ENDPOINT 5432"
    echo "  nc -zv $RDS_ENDPOINT 5432"
    echo "  psql -h $RDS_ENDPOINT -U postgres -d popcorn_db -c 'SELECT version();'"
    echo
fi

# 7. ElastiCache (Valkey) 연결 테스트
echo "7. ElastiCache (Valkey) 연결 테스트"
ELASTICACHE_CLUSTERS=$(aws elasticache describe-cache-clusters --region $REGION \
  --query 'CacheClusters[?contains(CacheClusterId, `popcorn`)].{ClusterId:CacheClusterId,Status:CacheClusterStatus,Engine:Engine,Endpoint:RedisConfiguration.PrimaryEndpoint.Address}' \
  --output table 2>/dev/null || echo "Redis 클러스터 정보를 가져올 수 없습니다.")
echo "$ELASTICACHE_CLUSTERS"

# Valkey/Redis 엔드포인트 정보
REDIS_ENDPOINT=$(aws elasticache describe-cache-clusters --region $REGION --show-cache-node-info \
  --query 'CacheClusters[?contains(CacheClusterId, `popcorn`)].CacheNodes[0].Endpoint.Address' --output text 2>/dev/null | head -1)

if [ -z "$REDIS_ENDPOINT" ]; then
    # Replication Group 확인 (클러스터 모드)
    REDIS_ENDPOINT=$(aws elasticache describe-replication-groups --region $REGION \
      --query 'ReplicationGroups[?contains(ReplicationGroupId, `popcorn`)].NodeGroups[0].PrimaryEndpoint.Address' --output text 2>/dev/null | head -1)
fi

if [ ! -z "$REDIS_ENDPOINT" ]; then
    echo "Valkey/Redis 엔드포인트: $REDIS_ENDPOINT"
    
    # 포트 연결 테스트 (ECS 컨테이너에서 실행할 명령어 예시)
    echo "ECS 컨테이너에서 Valkey/Redis 연결 테스트 명령어:"
    echo "  telnet $REDIS_ENDPOINT 6379"
    echo "  nc -zv $REDIS_ENDPOINT 6379"
    echo "  redis-cli -h $REDIS_ENDPOINT ping"
    echo "  redis-cli -h $REDIS_ENDPOINT info server"
    echo
fi

# 8. ECS 컨테이너에서 데이터베이스 연결 테스트 실행
echo "8. ECS 컨테이너에서 실제 연결 테스트"
echo "실행 중인 태스크에서 연결 테스트를 수행합니다..."

# 첫 번째 실행 중인 태스크 선택
FIRST_TASK=$(echo $TASKS | awk '{print $1}')
if [ ! -z "$FIRST_TASK" ]; then
    TASK_ID=$(basename $FIRST_TASK)
    echo "테스트 태스크: $TASK_ID"
    
    # 컨테이너 이름 확인
    CONTAINER_NAME=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $FIRST_TASK --region $REGION \
      --query 'tasks[0].containers[0].name' --output text)
    
    echo "컨테이너: $CONTAINER_NAME"
    echo
    
    if [ ! -z "$RDS_ENDPOINT" ]; then
        echo "RDS 연결 테스트 실행 중..."
        aws ecs execute-command \
          --cluster $CLUSTER_NAME \
          --task $FIRST_TASK \
          --container $CONTAINER_NAME \
          --interactive \
          --command "nc -zv $RDS_ENDPOINT 5432" \
          --region $REGION 2>/dev/null || echo "RDS 연결 테스트 실패 (ECS Exec이 활성화되지 않았을 수 있습니다)"
        echo
    fi
    
    if [ ! -z "$REDIS_ENDPOINT" ]; then
        echo "Valkey/Redis 연결 테스트 실행 중..."
        aws ecs execute-command \
          --cluster $CLUSTER_NAME \
          --task $FIRST_TASK \
          --container $CONTAINER_NAME \
          --interactive \
          --command "nc -zv $REDIS_ENDPOINT 6379" \
          --region $REGION 2>/dev/null || echo "Valkey/Redis 연결 테스트 실패 (ECS Exec이 활성화되지 않았을 수 있습니다)"
        echo
    fi
else
    echo "실행 중인 태스크가 없습니다."
fi

# 9. 수동 테스트 가이드
echo "9. 수동 연결 테스트 가이드"
echo "==================================="
echo
echo "ECS 컨테이너에 직접 접속하여 테스트하려면:"
echo
if [ ! -z "$FIRST_TASK" ]; then
    echo "1. ECS 컨테이너 접속:"
    echo "   aws ecs execute-command \\"
    echo "     --cluster $CLUSTER_NAME \\"
    echo "     --task $TASK_ID \\"
    echo "     --container $CONTAINER_NAME \\"
    echo "     --interactive \\"
    echo "     --command \"/bin/bash\" \\"
    echo "     --region $REGION"
    echo
fi

if [ ! -z "$RDS_ENDPOINT" ]; then
    echo "2. RDS PostgreSQL 연결 테스트:"
    echo "   # 포트 연결 확인"
    echo "   nc -zv $RDS_ENDPOINT 5432"
    echo "   telnet $RDS_ENDPOINT 5432"
    echo
    echo "   # PostgreSQL 클라이언트로 연결 (컨테이너에 psql이 설치된 경우)"
    echo "   psql -h $RDS_ENDPOINT -U postgres -d popcorn_db"
    echo "   psql -h $RDS_ENDPOINT -U postgres -d popcorn_db -c 'SELECT version();'"
    echo
fi

if [ ! -z "$REDIS_ENDPOINT" ]; then
    echo "3. Valkey/Redis 연결 테스트:"
    echo "   # 포트 연결 확인"
    echo "   nc -zv $REDIS_ENDPOINT 6379"
    echo "   telnet $REDIS_ENDPOINT 6379"
    echo
    echo "   # Redis 클라이언트로 연결 (컨테이너에 redis-cli가 설치된 경우)"
    echo "   redis-cli -h $REDIS_ENDPOINT ping"
    echo "   redis-cli -h $REDIS_ENDPOINT info"
    echo "   redis-cli -h $REDIS_ENDPOINT set test-key 'hello'"
    echo "   redis-cli -h $REDIS_ENDPOINT get test-key"
    echo
fi

echo "4. 애플리케이션 로그에서 연결 상태 확인:"
echo "   aws logs tail /aws/ecs/goorm-popcorn-dev-api-gateway --follow"
echo "   aws logs filter-log-events --log-group-name /aws/ecs/goorm-popcorn-dev-api-gateway --filter-pattern 'database'"
echo "   aws logs filter-log-events --log-group-name /aws/ecs/goorm-popcorn-dev-api-gateway --filter-pattern 'redis'"
echo

echo "=== 테스트 완료 ==="