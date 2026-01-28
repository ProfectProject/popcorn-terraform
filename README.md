# Popcorn MSA Terraform Infrastructure

## 개요

Popcorn MSA 프로젝트의 AWS 인프라를 Terraform으로 관리하는 Infrastructure as Code (IaC) 저장소입니다.

## 아키텍처

### 인프라 구성요소

- **VPC**: Multi-AZ 네트워크 구성
- **ECS Fargate**: 마이크로서비스 컨테이너 오케스트레이션
- **RDS PostgreSQL**: 관계형 데이터베이스
- **ElastiCache (Valkey)**: 인메모리 캐시
- **Application Load Balancer**: 로드 밸런싱 및 SSL 종료
- **EC2 Kafka**: 메시지 브로커 (KRaft 모드)
- **CloudMap**: 서비스 디스커버리
- **Route53**: DNS 관리

### 모니터링 구성요소

- **CloudWatch**: 로그 수집 및 메트릭 모니터링
- **Container Insights**: ECS 성능 모니터링
- **Performance Insights**: RDS 성능 분석
- **CloudWatch Alarms**: 자동 알림 시스템
- **CloudWatch Dashboards**: 통합 모니터링 대시보드

## 디렉토리 구조

```
popcorn-terraform-feature/
├── bootstrap/              # 초기 설정 (S3 백엔드, DynamoDB 락)
├── global/                 # 글로벌 리소스 (Route53, ECR)
├── envs/                   # 환경별 설정
│   ├── dev/               # 개발 환경
│   └── prod/              # 프로덕션 환경
├── modules/               # 재사용 가능한 Terraform 모듈
│   ├── vpc/
│   ├── ecs/
│   ├── rds/
│   ├── elasticache/
│   ├── alb/
│   ├── ec2-kafka/
│   ├── cloudmap/
│   ├── iam/
│   ├── security-groups/
│   ├── monitoring/        # 통합 모니터링 모듈
│   └── xray/             # X-Ray 분산 추적
├── docs/                  # 문서
│   ├── MONITORING.md      # 모니터링 가이드
│   └── CLOUDWATCH_SETUP.md # CloudWatch 설정 가이드
└── scripts/               # 유틸리티 스크립트
```

## 환경별 구성

### 개발 환경 (dev)
- **목적**: 개발 및 테스트
- **특징**: 단일 AZ, 최소 리소스, 비용 최적화
- **모니터링**: 기본 로그 수집, 7일 보존

### 프로덕션 환경 (prod)
- **목적**: 실제 서비스 운영
- **특징**: Multi-AZ, 고가용성, 성능 최적화
- **모니터링**: 전체 모니터링, 30일 보존

## 시작하기

### 사전 요구사항

1. **AWS CLI 설정**
   ```bash
   aws configure
   ```

2. **Terraform 설치** (v1.0+)
   ```bash
   # macOS
   brew install terraform
   
   # 또는 직접 다운로드
   # https://www.terraform.io/downloads.html
   ```

3. **필요한 권한**
   - EC2, VPC, RDS, ECS, ElastiCache 관리 권한
   - CloudWatch, SNS 관리 권한
   - S3, DynamoDB 접근 권한

### 초기 설정

1. **백엔드 초기화**
   ```bash
   cd bootstrap
   terraform init
   terraform apply
   ```

2. **글로벌 리소스 생성**
   ```bash
   cd global/route53-acm
   terraform init
   terraform apply
   
   cd ../ecr
   terraform init
   terraform apply
   ```

### 환경 배포

#### 개발 환경 배포
```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

#### 프로덕션 환경 배포
```bash
cd envs/prod
terraform init
terraform plan
terraform apply
```

## 모니터링 설정

### 현재 모니터링 상태

| 서비스 | 로그 수집 | 메트릭 | 알람 | 대시보드 |
|--------|-----------|--------|------|----------|
| ECS Fargate | ✅ | ✅ | ✅ | ✅ |
| RDS PostgreSQL | ✅ | ✅ | ⚠️ | ✅ |
| EC2 Kafka | ✅ | ⚠️ | ❌ | ⚠️ |
| ALB | ❌ | ✅ | ❌ | ⚠️ |
| ElastiCache | ❌ | ✅ | ❌ | ⚠️ |
| VPC | ❌ | ⚠️ | ❌ | ❌ |

### 추가 모니터링 활성화

자세한 설정 방법은 [CloudWatch 설정 가이드](docs/CLOUDWATCH_SETUP.md)를 참조하세요.

#### 기본 모니터링 추가
```bash
# terraform.tfvars에 추가
alert_email_addresses = ["admin@yourcompany.com"]
enable_alb_access_logs = true
enable_vpc_flow_logs = true
```

#### 통합 모니터링 모듈 활성화
```hcl
# main.tf에 추가
module "monitoring" {
  source = "../../modules/monitoring"
  
  name                    = var.name
  region                  = var.region
  alert_email_addresses  = var.alert_email_addresses
  
  # 기존 리소스 연결
  alb_arn_suffix         = module.alb.alb_arn_suffix
  rds_instance_id        = module.rds.instance_id
  elasticache_cluster_id = module.elasticache.cluster_id
  
  tags = var.tags
}
```

## 주요 명령어

### Terraform 기본 명령어
```bash
# 초기화
terraform init

# 계획 확인
terraform plan

# 배포
terraform apply

# 특정 리소스만 배포
terraform apply -target=module.monitoring

# 리소스 삭제
terraform destroy

# 상태 확인
terraform show

# 출력 값 확인
terraform output
```

### AWS CLI 유틸리티
```bash
# ECS 서비스 상태 확인
aws ecs describe-services --cluster goorm-popcorn-dev-cluster --services goorm-popcorn-dev-api-gateway

# RDS 인스턴스 상태 확인
aws rds describe-db-instances --db-instance-identifier goorm-popcorn-dev-postgres

# CloudWatch 로그 확인
aws logs describe-log-groups --log-group-name-prefix "/aws/ecs/goorm-popcorn"

# 알람 상태 확인
aws cloudwatch describe-alarms --alarm-name-prefix "goorm-popcorn-dev"
```

## 보안 고려사항

### 네트워크 보안
- 모든 데이터베이스는 private 서브넷에 배치
- Security Group으로 최소 권한 원칙 적용
- VPC Flow Logs로 네트워크 트래픽 모니터링

### 데이터 보안
- RDS 암호화 활성화
- ElastiCache 저장 시 암호화
- Secrets Manager로 민감 정보 관리

### 접근 제어
- IAM 역할 기반 최소 권한 부여
- ECS Exec을 통한 안전한 컨테이너 접근
- CloudTrail로 API 호출 감사

## 비용 최적화

### 개발 환경 최적화
- Spot 인스턴스 활용 (ECS Fargate Spot)
- 단일 AZ 배포로 NAT Gateway 비용 절약
- 짧은 로그 보존 기간 (7일)
- 최소 인스턴스 타입 사용

### 모니터링 비용 관리
- 불필요한 메트릭 비활성화
- 로그 필터링으로 저장 용량 최적화
- S3 Lifecycle 정책으로 오래된 로그 자동 삭제

## 문제 해결

### 일반적인 문제

#### Terraform 상태 잠금
```bash
# DynamoDB 테이블에서 잠금 해제
aws dynamodb delete-item --table-name terraform-locks --key '{"LockID":{"S":"your-lock-id"}}'
```

#### ECS 서비스 배포 실패
```bash
# 서비스 이벤트 확인
aws ecs describe-services --cluster your-cluster --services your-service --query 'services[0].events'

# 태스크 정의 확인
aws ecs describe-task-definition --task-definition your-task-definition
```

#### RDS 연결 문제
```bash
# 보안 그룹 규칙 확인
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx

# 서브넷 그룹 확인
aws rds describe-db-subnet-groups --db-subnet-group-name your-subnet-group
```

## 기여 가이드

### 코드 스타일
- Terraform 표준 포맷팅 사용: `terraform fmt`
- 변수와 출력에 설명 추가
- 태그 일관성 유지

### 변경 사항 제출
1. 기능 브랜치 생성
2. 변경 사항 구현
3. `terraform validate` 및 `terraform plan` 실행
4. Pull Request 생성
5. 코드 리뷰 후 병합

## 연락처

- **개발팀**: dev@yourcompany.com
- **DevOps팀**: devops@yourcompany.com
- **문의사항**: 이슈 트래커 활용

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.