# 개발 환경 구성 가이드

## 📋 개요

Goorm Popcorn 프로젝트의 개발 환경을 구성하는 가이드입니다. 변경된 스펙에 따라 단일 AZ 구성과 RDS PostgreSQL을 사용합니다.

## 🏗️ 변경된 아키텍처 스펙

### 📊 **환경별 구성**
| 환경 | AZ 구성 | 데이터베이스 | 특징 |
|------|---------|-------------|------|
| **Dev** | 단일 AZ | RDS PostgreSQL | 비용 최적화, 개발용 |
| **Prod** | 멀티 AZ | Aurora PostgreSQL | 고가용성, 운영용 |
| ~~Staging~~ | ~~제외~~ | ~~제외~~ | 구현하지 않음 |

### 🎯 **개발 환경 특징**
- **단일 AZ**: ap-northeast-2a만 사용
- **RDS PostgreSQL**: 단일 인스턴스 (db.t3.micro)
- **ECS Fargate**: 최소 리소스 (256 CPU, 512 Memory)
- **Kafka**: 단일 노드 (t3.micro)
- **ElastiCache**: 단일 노드 (cache.t4g.micro)

## 📁 생성된 모듈 구조

### ✅ **완성된 모듈들**

```
modules/
├── rds/                    # RDS PostgreSQL (Dev용)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── aurora/                 # Aurora PostgreSQL (Prod용)
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── iam/                    # IAM 역할
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ecs/                    # ECS Fargate
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── cloudmap/               # Service Discovery
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── ec2-kafka/              # Kafka (이미 완성)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── user_data.sh
```

## 🔗 모듈별 역할 및 연결 구조

### 1. **RDS PostgreSQL 모듈** (Dev 전용)

**역할**: 개발 환경용 단일 PostgreSQL 인스턴스 제공

**주요 기능**:
- 단일 AZ 배치 (비용 절약)
- db.t3.micro 인스턴스 (최소 비용)
- 자동 백업 1일 보존
- Secrets Manager 통합
- Performance Insights 비활성화 (비용 절약)

**연결점**:
```hcl
# envs/dev/main.tf에서 호출
module "rds" {
  source = "../../modules/rds"
  
  name              = var.rds_name
  environment       = "dev"
  subnet_ids        = values(module.vpc.data_subnet_ids)
  security_group_id = module.security_groups.db_sg_id
  
  # Dev 최적화 설정
  instance_class    = "db.t3.micro"
  multi_az         = false
  backup_retention_period = 1
}
```

**출력값**:
- `endpoint`: ECS에서 DB_HOST로 사용
- `master_password_secret_arn`: ECS에서 DB_PASSWORD로 사용

---

### 2. **Aurora PostgreSQL 모듈** (Prod 전용)

**역할**: 운영 환경용 고가용성 Aurora 클러스터 제공

**주요 기능**:
- 멀티 AZ 클러스터 (3개 인스턴스)
- Auto Scaling (2-10 Read Replicas)
- Performance Insights 활성화
- Enhanced Monitoring
- 7일 백업 보존

**연결점**:
```hcl
# envs/prod/main.tf에서 호출
module "aurora" {
  source = "../../modules/aurora"
  
  name              = var.aurora_name
  environment       = "prod"
  subnet_ids        = values(module.vpc.data_subnet_ids)
  security_group_id = module.security_groups.db_sg_id
  
  # Prod 최적화 설정
  instance_class    = "db.r6g.large"
  instance_count    = 3
  enable_autoscaling = true
}
```

---

### 3. **IAM 역할 모듈**

**역할**: ECS Task 실행 및 애플리케이션 권한 제공

**주요 역할**:
- **ECS Task Execution Role**: ECR 이미지 pull, CloudWatch 로그
- **ECS Task Role**: Secrets Manager, SSM 접근
- **Auto Scaling Role**: ECS 서비스 스케일링

**연결점**:
```hcl
# 모든 환경에서 공통 사용
module "iam" {
  source = "../../modules/iam"
  
  name        = var.iam_name
  environment = var.environment
  region      = var.region
}

# ECS 모듈에서 참조
module "ecs" {
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn          = module.iam.ecs_task_role_arn
}
```

---

### 4. **ECS Fargate 모듈**

**역할**: 6개 마이크로서비스 컨테이너 실행

**서비스 목록**:
1. **api-gateway**: Spring Cloud Gateway (ALB 연결)
2. **user-service**: 사용자 관리
3. **store-service**: 팝업 스토어 관리
4. **order-service**: 주문 처리 (Kafka 연결)
5. **payment-service**: 결제 처리 (Kafka 연결)
6. **qr-service**: QR 코드 생성/검증

**환경별 차이**:
```hcl
# Dev 환경 (최소 리소스)
services = {
  "api-gateway" = {
    cpu           = 256
    memory        = 512
    desired_count = 1
    min_capacity  = 1
    max_capacity  = 2
  }
}

# Prod 환경 (고성능 리소스)
services = {
  "api-gateway" = {
    cpu           = 512
    memory        = 1024
    desired_count = 2
    min_capacity  = 2
    max_capacity  = 4
  }
}
```

**자동 환경 변수 주입**:
```hcl
# 데이터베이스 연결 정보
DB_HOST = module.rds.endpoint          # Dev
DB_HOST = module.aurora.cluster_endpoint # Prod
DB_PASSWORD = secret_from_secrets_manager

# 캐시 연결 정보
REDIS_PRIMARY_ENDPOINT = module.elasticache.primary_endpoint

# Kafka 연결 정보
KAFKA_BOOTSTRAP_SERVERS = module.ec2_kafka.bootstrap_servers
```

---

### 5. **CloudMap 서비스 디스커버리 모듈**

**역할**: ECS 서비스 간 DNS 기반 통신 제공

**기능**:
- Private DNS Namespace: `goormpopcorn.local`
- 6개 서비스 자동 등록
- Health Check 통합

**서비스 DNS**:
```
api-gateway.goormpopcorn.local
user-service.goormpopcorn.local
store-service.goormpopcorn.local
order-service.goormpopcorn.local
payment-service.goormpopcorn.local
qr-service.goormpopcorn.local
```

**연결점**:
```hcl
# ECS 서비스에서 자동 등록
service_registries {
  registry_arn = module.cloudmap.service_arns["user-service"]
}

# 애플리케이션에서 사용
# http://user-service.goormpopcorn.local:8080/api/users
```

---

## 🔄 전체 연결 흐름

### 📊 **의존성 다이어그램**

```
┌─────────────────────────────────────────────────────────────┐
│                    Global Resources                         │
│  ┌──────────────┐  ┌──────────────────┐                    │
│  │     ECR      │  │  Route53 + ACM   │                    │
│  └──────────────┘  └──────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Dev Environment                            │
│  ┌──────────────┐  ┌──────────────────┐                    │
│  │     VPC      │  │  Security Groups │                    │
│  │  (단일 AZ)    │  │                  │                    │
│  └──────────────┘  └──────────────────┘                    │
│         ↓                    ↓                              │
│  ┌──────────────┐  ┌──────────────────┐                    │
│  │     ALB      │  │   ElastiCache    │                    │
│  │              │  │   (단일 노드)     │                    │
│  └──────────────┘  └──────────────────┘                    │
│         ↓                    ↓                              │
│  ┌──────────────┐  ┌──────────────────┐                    │
│  │  IAM Roles   │  │ RDS PostgreSQL   │                    │
│  │              │  │  (단일 인스턴스)   │                    │
│  └──────────────┘  └──────────────────┘                    │
│         ↓                    ↓                              │
│  ┌──────────────┐  ┌──────────────────┐                    │
│  │  CloudMap    │  │  EC2 Kafka       │                    │
│  │              │  │   (단일 노드)     │                    │
│  └──────────────┘  └──────────────────┘                    │
│         ↓                    ↓                              │
│  ┌─────────────────────────────────────┐                   │
│  │           ECS Fargate               │                   │
│  │        (6개 마이크로서비스)           │                   │
│  └─────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

### 🔗 **데이터 흐름**

1. **사용자 요청** → ALB → API Gateway (ECS)
2. **API Gateway** → 각 마이크로서비스 (CloudMap DNS)
3. **마이크로서비스** → RDS PostgreSQL (데이터 저장)
4. **마이크로서비스** → ElastiCache (캐싱)
5. **Order/Payment Service** → Kafka (이벤트 발행)

## 📋 다음 단계: 환경 설정 파일 업데이트

이제 생성된 모듈들을 사용하기 위해 다음 파일들을 업데이트해야 합니다:

### 1. **envs/dev/variables.tf 추가 변수**
```hcl
# RDS 관련
variable "rds_name" { type = string }
variable "rds_instance_class" { type = string, default = "db.t3.micro" }

# IAM 관련  
variable "iam_name" { type = string }

# ECS 관련
variable "ecs_name" { type = string }
variable "ecr_repository_url" { type = string }

# CloudMap 관련
variable "cloudmap_name" { type = string }
variable "cloudmap_namespace" { type = string, default = "goormpopcorn.local" }
```

### 2. **envs/dev/main.tf 모듈 호출**
```hcl
module "iam" {
  source = "../../modules/iam"
  # ... 설정
}

module "rds" {
  source = "../../modules/rds"
  # ... 설정
}

module "cloudmap" {
  source = "../../modules/cloudmap"
  # ... 설정
}

module "ecs" {
  source = "../../modules/ecs"
  # ... 설정
}
```

### 3. **envs/dev/terraform.tfvars 값 추가**
```hcl
# 기존 값들...

# 새로 추가할 값들
rds_name = "goorm-popcorn-dev"
iam_name = "goorm-popcorn-dev"
ecs_name = "goorm-popcorn-dev"
cloudmap_name = "goorm-popcorn-dev"
ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com"
```

이 파일들을 업데이트해도 괜찮으신가요? 아니면 모듈 생성만으로 충분하신가요?

## 💰 예상 비용 (Dev 환경)

| 서비스 | 스펙 | 월 비용 (USD) |
|--------|------|---------------|
| RDS PostgreSQL | db.t3.micro | $13 |
| ECS Fargate | 6 tasks × 256 CPU | $45 |
| EC2 Kafka | t3.micro | $8.5 |
| ElastiCache | cache.t4g.micro | $11 |
| ALB | 고정 + 처리량 | $16 |
| NAT Gateway | 1개 | $32 |
| **총계** | | **~$125** |

개발 환경이 월 $125 정도로 매우 경제적입니다!

## ✅ 체크리스트

- [x] RDS PostgreSQL 모듈 생성
- [x] Aurora PostgreSQL 모듈 생성 (Prod용)
- [x] IAM 역할 모듈 생성
- [x] ECS Fargate 모듈 생성
- [x] CloudMap 서비스 디스커버리 모듈 생성
- [x] EC2 Kafka 모듈 (이미 완성)
- [ ] 환경 설정 파일 업데이트
- [ ] Terraform 초기화 및 배포
- [ ] 서비스 간 통신 테스트