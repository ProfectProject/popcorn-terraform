# Goorm Popcorn - Terraform 배포 가이드

이 문서는 Goorm Popcorn 인프라를 Terraform으로 배포하는 방법을 설명합니다.

## 사전 요구사항

### 1. 도구 설치

```bash
# Terraform 설치 (macOS)
brew install terraform

# AWS CLI 설치
brew install awscli

# AWS CLI 설정
aws configure
```

### 2. AWS 권한 설정

다음 권한이 필요합니다:
- VPC, EC2, ECS 관리
- RDS, ElastiCache 관리
- MSK, CloudMap 관리
- IAM, Secrets Manager 관리
- Route 53, ACM 관리
- S3, DynamoDB 관리

### 3. Terraform State 백엔드 준비

```bash
# S3 버킷 생성 (각 환경별)
aws s3 mb s3://goorm-popcorn-terraform-state-global
aws s3 mb s3://goorm-popcorn-terraform-state-dev
aws s3 mb s3://goorm-popcorn-terraform-state-staging
aws s3 mb s3://goorm-popcorn-terraform-state-prod

# DynamoDB 테이블 생성 (State Lock용)
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

## 배포 순서

### 1. 글로벌 리소스 배포

#### ECR 레포지토리 생성

```bash
cd terraform/global/ecr
terraform init
terraform plan
terraform apply
```

#### Route 53 및 ACM 인증서

```bash
cd terraform/global/route53
terraform init

# terraform.tfvars 파일 생성
cat > terraform.tfvars << EOF
domain_name = "goormpopcron.shop"
EOF

terraform plan
terraform apply

# 도메인 네임서버 설정 (도메인 등록업체에서)
terraform output hosted_zone_name_servers
```

### 2. 개발 환경 배포 (최소 비용)

```bash
cd terraform/environments/dev

# terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars

# 필요한 값들 수정
vim terraform.tfvars
```

**Dev 환경 terraform.tfvars 예시:**
```hcl
# AWS Configuration
aws_region   = "ap-northeast-2"
project_name = "goorm-popcorn"
environment  = "dev"

# SSL Certificate ARN (Route 53에서 생성된 것)
certificate_arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/..."

# ECR Repository URL (ECR에서 생성된 것)
ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com"

# Network Configuration - 개발용 별도 CIDR
vpc_cidr = "10.1.0.0/16"
public_subnet_cidrs = ["10.1.1.0/24"]
private_app_subnet_cidrs = ["10.1.11.0/24"]
private_data_subnet_cidrs = ["10.1.21.0/24"]

# 비용 절감 설정
enable_vpc_endpoints = false  # NAT Gateway 사용 (비용 절감)

# Database Configuration - 최소 사양
database_name = "goorm_popcorn_dev"
aurora_instance_class = "db.t4g.medium"  # 작은 인스턴스
aurora_instance_count = 1                # Writer만

# Cache Configuration - 최소 사양
elasticache_node_type = "cache.t4g.micro"  # 가장 작은 인스턴스
```

```bash
# 배포 실행
terraform init
terraform plan
terraform apply

# 예상 비용: ~$150/월
```

### 3. 스테이징 환경 배포

```bash
cd terraform/environments/staging

# terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars

# 필요한 값들 수정
vim terraform.tfvars
```

**Staging 환경 terraform.tfvars 예시:**
```hcl
# AWS Configuration
aws_region   = "ap-northeast-2"
project_name = "goorm-popcorn"
environment  = "staging"

# SSL Certificate ARN (Route 53에서 생성된 것)
certificate_arn = "arn:aws:acm:ap-northeast-2:123456789012:certificate/..."

# ECR Repository URL
ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com"

# Database Configuration - 중간 사양
database_name = "goorm_popcorn_staging"
aurora_instance_count = 2  # Writer + Reader 1개

# Cache Configuration
elasticache_node_type = "cache.t4g.micro"
```

```bash
# 배포 실행
terraform init
terraform plan
terraform apply

# 예상 비용: ~$400/월
```

### 4. 프로덕션 환경 배포

```bash
cd terraform/environments/prod

# terraform.tfvars 파일 생성
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 배포 실행
terraform init
terraform plan
terraform apply

# 예상 비용: ~$765/월
```

## 환경별 비용 비교

| 환경 | 월 비용 | 주요 차이점 |
|------|---------|-------------|
| **Dev** | **~$150** | 단일 AZ, 최소 인스턴스, Auto Scaling 비활성화 |
| **Staging** | **~$400** | Multi-AZ, 중간 사양, 제한적 Auto Scaling |
| **Production** | **~$765** | Multi-AZ, 고사양, 완전 Auto Scaling, 30일 백업 |

## 환경별 주요 차이점

### Dev 환경 (개발/테스트)
- **단일 AZ**: 비용 절감 우선
- **최소 인스턴스**: db.t4g.medium, cache.t4g.micro
- **Auto Scaling 비활성화**: 예측 가능한 비용
- **VPC Endpoints 비활성화**: NAT Gateway 사용
- **로그 보존**: 3일
- **백업**: 1일

### Staging 환경 (QA/통합테스트)
- **Multi-AZ**: Production 유사 환경
- **중간 사양**: db.r6g.large, cache.t4g.micro
- **제한적 Auto Scaling**: 2-8개 인스턴스
- **VPC Endpoints 활성화**: 보안 강화
- **로그 보존**: 7일
- **백업**: 7일

### Production 환경 (실제 서비스)
- **Multi-AZ**: 최고 가용성
- **고사양**: db.r6g.large, cache.t4g.small
- **완전 Auto Scaling**: 2-30개 인스턴스
- **모든 기능 활성화**: 모니터링, 백업, 보안
- **로그 보존**: 30일
- **백업**: 30일

## 배포 후 설정

### 1. 도메인 DNS 설정

Route 53에서 출력된 네임서버를 도메인 등록업체에 설정:

```bash
cd terraform/global/route53
terraform output hosted_zone_name_servers
```

### 2. ECR 이미지 푸시

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드 및 푸시 (각 서비스별)
docker build -t goorm-popcorn/api-gateway .
docker tag goorm-popcorn/api-gateway:latest 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn/api-gateway:latest
docker push 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn/api-gateway:latest
```

### 3. 데이터베이스 초기화

```bash
# Aurora 엔드포인트 확인
cd terraform/environments/staging
terraform output aurora_cluster_endpoint

# 데이터베이스 스키마 생성
psql -h <aurora-endpoint> -U postgres -d goorm_popcorn_staging < schema.sql
```

### 4. Secrets Manager 설정

```bash
# 추가 시크릿 생성 (PG API 키 등)
aws secretsmanager create-secret \
  --name "goorm-popcorn/staging/payment/pg-api-key" \
  --description "Payment Gateway API Key" \
  --secret-string "your-pg-api-key"
```

## 모니터링 설정

### 1. CloudWatch 대시보드

```bash
# 대시보드 생성 스크립트 실행
aws cloudwatch put-dashboard \
  --dashboard-name "GoormPopcorn-Staging" \
  --dashboard-body file://cloudwatch-dashboard.json
```

### 2. 알람 설정

주요 메트릭에 대한 알람이 자동으로 생성됩니다:
- ECS CPU/Memory 사용률
- Aurora CPU/연결 수
- ElastiCache 메모리/히트율
- ALB 응답 시간/에러율

## 운영 가이드

### 서비스 스케일링

```bash
# ECS 서비스 수동 스케일링
aws ecs update-service \
  --cluster goorm-popcorn-cluster \
  --service goorm-popcorn-user-service \
  --desired-count 5
```

### 배포 롤백

```bash
# 이전 태스크 정의로 롤백
aws ecs update-service \
  --cluster goorm-popcorn-cluster \
  --service goorm-popcorn-user-service \
  --task-definition goorm-popcorn-user-service:123
```

### 로그 확인

```bash
# CloudWatch Logs 확인
aws logs tail /aws/ecs/goorm-popcorn/user-service --follow
```

### 데이터베이스 접속

```bash
# SSM Session Manager를 통한 접속
aws ssm start-session --target <ecs-task-id>

# 컨테이너 내에서 데이터베이스 접속
psql -h <aurora-endpoint> -U postgres -d goorm_popcorn_staging
```

## 비용 최적화

### 1. Fargate Spot 활용

```bash
# Spot 인스턴스 비율 확인
aws ecs describe-services \
  --cluster goorm-popcorn-cluster \
  --services goorm-popcorn-user-service
```

### 2. Aurora Auto Scaling 모니터링

```bash
# Aurora 인스턴스 수 확인
aws rds describe-db-clusters \
  --db-cluster-identifier goorm-popcorn-aurora-cluster
```

### 3. 비용 알람 설정

```bash
# 월 예산 알람 설정
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget.json
```

## 문제 해결

### 일반적인 문제들

1. **ECS 태스크 시작 실패**
   - CloudWatch Logs에서 에러 확인
   - IAM 권한 확인
   - 시크릿 값 확인

2. **데이터베이스 연결 실패**
   - Security Group 규칙 확인
   - 네트워크 연결 확인
   - 자격 증명 확인

3. **MSK 연결 실패**
   - IAM 정책 확인
   - Security Group 확인
   - 부트스트랩 서버 주소 확인

### 로그 수집

```bash
# 모든 서비스 로그 수집
for service in api-gateway user-service store-service order-service payment-service qr-service; do
  aws logs create-export-task \
    --log-group-name "/aws/ecs/goorm-popcorn/$service" \
    --from $(date -d '1 hour ago' +%s)000 \
    --to $(date +%s)000 \
    --destination "goorm-popcorn-logs" \
    --destination-prefix "$service/"
done
```

## 보안 체크리스트

- [ ] 모든 민감정보가 Secrets Manager에 저장됨
- [ ] Security Groups가 최소 권한으로 설정됨
- [ ] VPC Endpoints가 활성화됨
- [ ] 암호화가 모든 곳에 적용됨 (전송/저장)
- [ ] IAM 역할이 최소 권한 원칙을 따름
- [ ] CloudTrail 로깅이 활성화됨

## 지원

문제가 발생하면 다음 채널로 연락하세요:
- Infrastructure Team: infra@goormpopcorn.shop
- Slack: #infrastructure
- 긴급상황: PagerDuty