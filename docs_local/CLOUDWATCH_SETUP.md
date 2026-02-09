# CloudWatch 모니터링 설정 가이드

## 목차
1. [현재 모니터링 상태](#현재-모니터링-상태)
2. [추가 모니터링 설정](#추가-모니터링-설정)
3. [모듈별 설정 방법](#모듈별-설정-방법)
4. [배포 가이드](#배포-가이드)

## 현재 모니터링 상태

### ✅ 활성화된 모니터링

| 서비스 | 모니터링 항목 | 상태 |
|--------|---------------|------|
| ECS Fargate | 로그 수집, Container Insights, 오토스케일링 | ✅ 활성화 |
| RDS PostgreSQL | 로그 내보내기, Performance Insights | ✅ 활성화 |
| EC2 Kafka | 로그 수집 | ✅ 활성화 |

### ❌ 미설정 모니터링

| 서비스 | 모니터링 항목 | 우선순위 |
|--------|---------------|----------|
| ALB | 액세스 로그, 메트릭 알람 | 🔴 높음 |
| ElastiCache | 성능 메트릭, 알람 | 🟡 중간 |
| VPC | Flow Logs, 네트워크 모니터링 | 🟡 중간 |
| X-Ray | 분산 추적 | 🟢 낮음 |

## 추가 모니터링 설정

### 1단계: 기본 모니터링 모듈 추가 (SNS 없이)

```hcl
# envs/dev/main.tf에 추가
module "monitoring" {
  source = "../../modules/monitoring"
  
  name                    = var.name
  region                  = var.region
  alb_arn_suffix         = module.alb.alb_arn_suffix
  rds_instance_id        = module.rds.instance_id
  elasticache_cluster_id = module.elasticache.cluster_id
  
  # SNS 알림은 선택적 (기본값: false)
  enable_sns_alerts      = false
  
  tags = var.tags
}
```

### 1단계 (대안): SNS 알림 포함 모니터링

```hcl
# envs/dev/main.tf에 추가 (이메일 알림 원하는 경우)
module "monitoring" {
  source = "../../modules/monitoring"
  
  name                    = var.name
  region                  = var.region
  alb_arn_suffix         = module.alb.alb_arn_suffix
  rds_instance_id        = module.rds.instance_id
  elasticache_cluster_id = module.elasticache.cluster_id
  
  # SNS 알림 활성화
  enable_sns_alerts      = true
  alert_email_addresses  = var.alert_email_addresses
  
  tags = var.tags
}
```

### 2단계: 기존 모듈에 모니터링 설정 추가

#### ALB 모듈 업데이트
```hcl
module "alb" {
  source = "../../modules/alb"
  
  # 기존 설정...
  
  # 모니터링 설정 추가
  enable_access_logs       = var.enable_alb_access_logs
  access_logs_bucket       = var.alb_access_logs_bucket
  access_logs_prefix       = "alb"
  enable_cloudwatch_alarms = true
  sns_topic_arn           = module.monitoring.sns_topic_arn  # SNS 활성화시에만 사용
}
```

#### ElastiCache 모듈 업데이트
```hcl
module "elasticache" {
  source = "../../modules/elasticache"
  
  # 기존 설정...
  
  # 모니터링 설정 추가
  enable_cloudwatch_alarms = true
  sns_topic_arn           = module.monitoring.sns_topic_arn  # SNS 활성화시에만 사용
}
```

#### VPC 모듈 업데이트
```hcl
module "vpc" {
  source = "../../modules/vpc"
  
  # 기존 설정...
  
  # Flow Logs 설정 추가
  enable_flow_logs         = var.enable_vpc_flow_logs
  flow_logs_retention_days = var.vpc_flow_logs_retention_days
  sns_topic_arn           = module.monitoring.sns_topic_arn
}
```

### 3단계: 변수 추가

#### terraform.tfvars에 추가 (기본 모니터링)
```hcl
# 기본 모니터링 설정 (SNS 없이)
enable_alb_access_logs = false  # S3 비용 절약을 위해 비활성화
```

#### terraform.tfvars에 추가 (SNS 알림 포함)
```hcl
# 모니터링 설정 (SNS 알림 포함)
alert_email_addresses = ["admin@yourcompany.com", "devops@yourcompany.com"]

# ALB 모니터링
enable_alb_access_logs = true
alb_access_logs_bucket = "goorm-popcorn-alb-logs-dev"

# VPC Flow Logs
enable_vpc_flow_logs         = true
vpc_flow_logs_retention_days = 7
```

#### 변수 정의 (variables.tf)
```hcl
# 모니터링 관련 변수 (선택적)
variable "alert_email_addresses" {
  description = "Email addresses to receive alerts (only used if SNS is enabled)"
  type        = list(string)
  default     = []
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type        = string
  default     = null
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "vpc_flow_logs_retention_days" {
  description = "VPC Flow Logs retention days"
  type        = number
  default     = 7
}
```

## 모듈별 설정 방법

### ALB 모니터링 모듈

#### 파일 구조
```
modules/alb/
├── main.tf
├── variables.tf
├── outputs.tf
└── cloudwatch.tf  # 새로 추가됨
```

#### 주요 기능
- S3 버킷에 액세스 로그 저장
- 응답시간, 4xx/5xx 에러율 알람
- 자동 로그 정리 (30일 후 삭제)

### ElastiCache 모니터링 모듈

#### 파일 구조
```
modules/elasticache/
├── main.tf
├── variables.tf
├── outputs.tf
└── cloudwatch.tf  # 새로 추가됨
```

#### 주요 기능
- CPU/메모리 사용률 모니터링
- 연결 수 및 캐시 히트율 추적
- 성능 임계값 기반 알람

### VPC 모니터링 모듈

#### 파일 구조
```
modules/vpc/
├── main.tf
├── variables.tf
├── outputs.tf
└── flow-logs.tf  # 새로 추가됨
```

#### 주요 기능
- VPC Flow Logs 수집
- 거부된 트래픽 모니터링
- 네트워크 보안 이벤트 알람

### 통합 모니터링 모듈

#### 파일 구조
```
modules/monitoring/
├── main.tf
├── variables.tf
└── outputs.tf
```

#### 주요 기능
- 통합 CloudWatch 대시보드
- SNS 알림 설정
- 이메일 알람 구독

## 배포 가이드

### 1단계: 설정 검증
```bash
cd popcorn-terraform-feature/envs/dev
terraform validate
```

### 2단계: 계획 확인
```bash
terraform plan
```

### 3단계: 단계별 배포

#### 3-1. 모니터링 모듈만 먼저 배포
```bash
terraform apply -target=module.monitoring
```

#### 3-2. ALB 모니터링 추가
```bash
terraform apply -target=module.alb
```

#### 3-3. 전체 배포
```bash
terraform apply
```

### 4단계: 배포 후 확인

#### SNS 구독 확인
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw monitoring_sns_topic_arn)
```

#### 대시보드 접근
```bash
# 대시보드 URL 출력
terraform output monitoring_dashboard_url
```

#### 알람 상태 확인
```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix "goorm-popcorn-dev"
```

## 설정 예제

### 개발 환경 (최소 설정 - SNS 없이)
```hcl
# terraform.tfvars
enable_alb_access_logs = false
enable_vpc_flow_logs = false
# SNS 관련 설정 불필요
```

### 스테이징 환경 (중간 설정 - SNS 포함)
```hcl
# terraform.tfvars
alert_email_addresses = ["dev@company.com", "qa@company.com"]
enable_alb_access_logs = true
enable_vpc_flow_logs = true
vpc_flow_logs_retention_days = 14
```

### 프로덕션 환경 (전체 설정 - SNS 포함)
```hcl
# terraform.tfvars
alert_email_addresses = ["ops@company.com", "dev@company.com", "manager@company.com"]
enable_alb_access_logs = true
enable_vpc_flow_logs = true
vpc_flow_logs_retention_days = 30

# X-Ray 추가
enable_xray_tracing = true
```

## 비용 영향 분석

### 예상 월간 비용 (dev 환경 - SNS 없이)

| 서비스 | 항목 | 예상 비용 (USD) |
|--------|------|----------------|
| CloudWatch Logs | 로그 수집 (5GB/월) | $2.50 |
| CloudWatch Metrics | 기본 메트릭 | $0.00 |
| CloudWatch Alarms | 알람 (20개) | $2.00 |
| CloudWatch Dashboards | 대시보드 (1개) | $3.00 |
| **총계** | | **$7.50** |

### 예상 월간 비용 (dev 환경 - SNS 포함)

| 서비스 | 항목 | 예상 비용 (USD) |
|--------|------|----------------|
| CloudWatch Logs | 로그 수집 (5GB/월) | $2.50 |
| CloudWatch Metrics | 기본 메트릭 | $0.00 |
| CloudWatch Alarms | 알람 (20개) | $2.00 |
| CloudWatch Dashboards | 대시보드 (1개) | $3.00 |
| S3 | ALB 로그 저장 (10GB/월) | $0.25 |
| SNS | 알림 (1000건/월) | $0.50 |
| **총계** | | **$8.25** |

### 비용 최적화 방법
1. **로그 보존 기간 단축**: dev 환경은 7일로 설정
2. **불필요한 메트릭 제거**: 사용하지 않는 메트릭 비활성화
3. **알람 통합**: 유사한 알람을 하나로 통합
4. **S3 Lifecycle**: 오래된 로그 자동 삭제

## 문제 해결

### 자주 발생하는 문제

#### 1. S3 버킷 권한 오류
```bash
# 해결 방법: ALB 서비스 계정에 권한 부여
aws s3api put-bucket-policy --bucket your-alb-logs-bucket --policy file://alb-logs-policy.json
```

#### 2. SNS 구독 확인 필요 (SNS 활성화시에만)
```bash
# 이메일 확인 후 구독 승인 필요
# AWS Console에서 확인하거나 이메일에서 "Confirm subscription" 클릭
```

#### 3. CloudWatch 에이전트 권한 부족
```bash
# IAM 역할에 CloudWatchAgentServerPolicy 정책 추가
aws iam attach-role-policy \
  --role-name your-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

## 다음 단계

1. **기본 모니터링 배포**: ALB, ElastiCache 모니터링 우선 적용
2. **알람 튜닝**: 실제 운영 데이터를 바탕으로 임계값 조정
3. **대시보드 커스터마이징**: 팀 요구사항에 맞게 위젯 추가/수정
4. **자동화 개선**: Terraform 모듈 재사용성 향상
5. **고급 모니터링**: X-Ray, Custom Metrics 추가 검토