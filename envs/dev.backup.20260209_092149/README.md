# 개발 환경 (Dev) 배포 가이드

## 📋 개요

Goorm Popcorn 프로젝트의 개발 환경을 배포하는 가이드입니다.

## 🏗️ 아키텍처

### 📊 **개발 환경 스펙**
- **AZ**: 단일 AZ (ap-northeast-2a)
- **데이터베이스**: RDS PostgreSQL (db.t3.micro)
- **컨테이너**: ECS Fargate (256 CPU, 512 Memory)
- **캐시**: ElastiCache Redis (cache.t4g.micro)
- **메시징**: EC2 Kafka (t3.micro, 단일 노드)

### 💰 **예상 비용**: ~$125/월

## 🚀 배포 전 준비사항

### 1. **필수 리소스 확인**
```bash
# 1. Global 리소스가 배포되어 있는지 확인
aws s3 ls s3://goorm-popcorn-tfstate/global/

# 2. ECR 리포지토리 URL 확인
aws ecr describe-repositories --region ap-northeast-2

# 3. EC2 키페어 생성 (없는 경우)
aws ec2 create-key-pair --key-name goorm-popcorn-keypair --region ap-northeast-2
```

### 2. **terraform.tfvars 수정**
```bash
# terraform.tfvars에서 다음 값들을 실제 값으로 변경
ecr_repository_url = "실제_ECR_URL"
ec2_kafka_key_name = "실제_키페어_이름"
```

## 📦 배포 순서

### 1. **Terraform 초기화**
```bash
cd envs/dev
terraform init
```

### 2. **배포 계획 확인**
```bash
terraform plan
```

### 3. **배포 실행**
```bash
terraform apply
```

## 🔍 배포 후 확인사항

### 1. **인프라 상태 확인**
```bash
# VPC 및 서브넷 확인
terraform output vpc_id
terraform output app_subnet_ids

# 데이터베이스 연결 확인
terraform output rds_endpoint

# Kafka 클러스터 확인
terraform output kafka_bootstrap_servers

# ECS 클러스터 확인
terraform output ecs_cluster_name
```

### 2. **서비스 상태 확인**
```bash
# ECS 서비스 상태
aws ecs list-services --cluster $(terraform output -raw ecs_cluster_name)

# RDS 인스턴스 상태
aws rds describe-db-instances --db-instance-identifier goorm-popcorn-dev-postgres

# ElastiCache 클러스터 상태
aws elasticache describe-cache-clusters --cache-cluster-id goorm-popcorn-cache-dev

# Kafka 인스턴스 상태 (SSH 접속 후)
ssh -i ~/.ssh/goorm-popcorn-keypair.pem ec2-user@<kafka-private-ip>
sudo /opt/kafka/scripts/status.sh
```

## 🔗 서비스 연결 정보

### **데이터베이스 연결**
```bash
# 엔드포인트 확인
DB_HOST=$(terraform output -raw rds_endpoint)
DB_PORT=5432
DB_NAME=goorm_popcorn_db

# 비밀번호는 Secrets Manager에서 확인
aws secretsmanager get-secret-value --secret-id $(terraform output -raw rds_secret_arn)
```

### **Redis 연결**
```bash
# 엔드포인트 확인
REDIS_HOST=$(terraform output -raw elasticache_primary_endpoint)
REDIS_PORT=6379
```

### **Kafka 연결**
```bash
# Bootstrap servers 확인
KAFKA_BOOTSTRAP_SERVERS=$(terraform output -raw kafka_bootstrap_servers)
```

### **서비스 디스커버리**
```bash
# CloudMap 네임스페이스
NAMESPACE=$(terraform output -raw cloudmap_namespace_name)

# 서비스 DNS 주소
api-gateway.goormpopcorn.local:8080
user-service.goormpopcorn.local:8080
store-service.goormpopcorn.local:8080
order-service.goormpopcorn.local:8080
payment-service.goormpopcorn.local:8080
qr-service.goormpopcorn.local:8080
```

## 🐳 컨테이너 이미지 배포

### 1. **ECR 로그인**
```bash
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d'/' -f1)
```

### 2. **이미지 빌드 및 푸시**
```bash
# 각 서비스별로 실행
SERVICE_NAME="api-gateway"  # user-service, store-service, order-service, payment-service, qr-service

docker build -t $SERVICE_NAME .
docker tag $SERVICE_NAME:latest $(terraform output -raw ecr_repository_url)/goorm-popcorn-dev/$SERVICE_NAME:latest
docker push $(terraform output -raw ecr_repository_url)/goorm-popcorn-dev/$SERVICE_NAME:latest
```

### 3. **ECS 서비스 업데이트**
```bash
# 새 이미지로 서비스 업데이트
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service goorm-popcorn-dev-$SERVICE_NAME \
  --force-new-deployment
```

## 🔧 트러블슈팅

### **일반적인 문제들**

1. **ECR 권한 오류**
```bash
# ECR 정책 확인
aws ecr get-repository-policy --repository-name goorm-popcorn-dev/api-gateway
```

2. **ECS 태스크 시작 실패**
```bash
# 태스크 로그 확인
aws logs get-log-events \
  --log-group-name /aws/ecs/goorm-popcorn-dev/api-gateway \
  --log-stream-name ecs/api-gateway/$(date +%Y/%m/%d)
```

3. **데이터베이스 연결 실패**
```bash
# 보안 그룹 규칙 확인
aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_ids)

# RDS 상태 확인
aws rds describe-db-instances --db-instance-identifier goorm-popcorn-dev-postgres
```

4. **Kafka 연결 실패**
```bash
# Kafka 인스턴스 SSH 접속
ssh -i ~/.ssh/goorm-popcorn-keypair.pem ec2-user@$(terraform output -raw kafka_private_ips | jq -r '.[0]')

# Kafka 서비스 상태 확인
sudo systemctl status kafka
sudo /opt/kafka/scripts/status.sh
```

## 🗑️ 리소스 정리

### **개발 환경 삭제**
```bash
# 주의: 모든 데이터가 삭제됩니다!
terraform destroy

# 확인 후 실행
# yes 입력
```

### **부분 삭제 (특정 리소스만)**
```bash
# 특정 모듈만 삭제
terraform destroy -target=module.ecs
terraform destroy -target=module.ec2_kafka
```

## 📊 모니터링

### **CloudWatch 대시보드**
- ECS 서비스 메트릭: CPU, Memory 사용률
- RDS 메트릭: 연결 수, CPU, 스토리지
- ElastiCache 메트릭: 캐시 히트율, 연결 수
- Kafka 메트릭: 커스텀 메트릭 (CloudWatch Agent)

### **로그 확인**
```bash
# ECS 서비스 로그
aws logs tail /aws/ecs/goorm-popcorn-dev/api-gateway --follow

# Kafka 설치 로그
aws logs tail /aws/ec2/kafka-dev --follow
```

## 🔄 업데이트 및 유지보수

### **정기 업데이트**
1. **주간**: 컨테이너 이미지 업데이트
2. **월간**: Terraform 모듈 업데이트
3. **분기**: 인스턴스 타입 및 비용 최적화 검토

### **백업 확인**
```bash
# RDS 자동 백업 확인
aws rds describe-db-snapshots --db-instance-identifier goorm-popcorn-dev-postgres

# ElastiCache 백업 (수동)
aws elasticache create-snapshot \
  --cache-cluster-id goorm-popcorn-cache-dev \
  --snapshot-name dev-backup-$(date +%Y%m%d)
```