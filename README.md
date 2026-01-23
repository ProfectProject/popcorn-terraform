# popcorn-terraform

Goorm Popcorn 프로젝트의 AWS 인프라를 Terraform으로 관리합니다.

## 🎯 변경된 스펙 (2024-01-23)

### 📊 **환경별 구성**
| 환경 | AZ 구성 | 데이터베이스 | 특징 |
|------|---------|-------------|------|
| **Dev** | 단일 AZ | RDS PostgreSQL | 비용 최적화, 개발용 (~$125/월) |
| **Prod** | 멀티 AZ | Aurora PostgreSQL | 고가용성, 운영용 (~$500/월) |
| ~~Staging~~ | ~~제외~~ | ~~제외~~ | 구현하지 않음 |

## 요구사항 및 버전 정책
- Terraform >= 1.4.0
- AWS Provider ~> 5.0
- AWS CLI >= 2.0 (AssumeRole 프로파일 설정 필요)

Terraform과 Provider 버전은 모든 스택에서 동일하게 고정하고,
각 스택의 `versions.tf`로 명시적으로 관리합니다.
공통 템플릿은 `templates/versions.tf`를 사용합니다.

## 디렉토리 구조
```
.
├── bootstrap/                  # Terraform 백엔드 초기화
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
├── envs/
│   ├── dev/                   # 개발 환경 (단일 AZ + RDS PostgreSQL)
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   ├── versions.tf
│   │   └── README.md
│   └── prod/                  # 운영 환경 (멀티 AZ + Aurora PostgreSQL)
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       └── versions.tf
├── global/
│   ├── ecr/                   # ECR 리포지토리 (6개 서비스)
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   └── versions.tf
│   └── route53-acm/           # Route53 + ACM 인증서
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       └── versions.tf
├── modules/
│   ├── vpc/                   # VPC 및 서브넷 (3-Tier)
│   ├── security-groups/       # 보안 그룹 (ALB/ECS/DB/Cache/Kafka)
│   ├── alb/                   # Application Load Balancer
│   ├── elasticache/           # Redis 클러스터
│   ├── rds/                   # RDS PostgreSQL (Dev용)
│   ├── aurora/                # Aurora PostgreSQL (Prod용)
│   ├── iam/                   # IAM 역할 (ECS Task, Auto Scaling)
│   ├── ecs/                   # ECS Fargate (6개 마이크로서비스)
│   ├── cloudmap/              # Service Discovery
│   ├── ec2-kafka/             # EC2 Kafka KRaft 클러스터
│   ├── ecr/                   # ECR 리포지토리
│   └── route53-acm/           # Route53 + ACM
├── docs/
│   ├── dev-environment-guide.md      # 개발 환경 구성 가이드
│   └── ec2-kafka-module-guide.md     # Kafka 모듈 가이드
├── templates/
│   └── versions.tf
└── README.md
```

## 🏗️ 현재 구성된 리소스

### ✅ **완성된 모듈들**

#### **기본 인프라**
- **VPC**: 3-Tier 아키텍처 (Public/App/Data 서브넷)
- **Security Groups**: 계층별 보안 그룹 (ALB/ECS/DB/Cache/Kafka)
- **ALB**: HTTPS 리다이렉트, Path 기반 라우팅
- **ElastiCache**: Redis 클러스터 (캐싱)

#### **데이터베이스** (환경별 분리)
- **RDS PostgreSQL**: Dev 환경용 (단일 인스턴스, db.t3.micro)
- **Aurora PostgreSQL**: Prod 환경용 (클러스터, Auto Scaling)

#### **컨테이너 플랫폼**
- **ECS Fargate**: 6개 마이크로서비스 배포
- **CloudMap**: 서비스 디스커버리 (DNS 기반)
- **IAM**: ECS Task 실행 및 애플리케이션 권한

#### **메시징**
- **EC2 Kafka**: KRaft 모드 (ZooKeeper 없음)
  - Dev: 단일 노드 (t3.micro)
  - Prod: 3노드 클러스터 (t3.small)

#### **전역 리소스**
- **ECR**: 6개 서비스용 컨테이너 레지스트리
- **Route53 + ACM**: 도메인 및 SSL 인증서

### 🎯 **마이크로서비스 구성**

| 서비스 | 역할 | 포트 | 연결 |
|--------|------|------|------|
| **api-gateway** | Spring Cloud Gateway | 8080 | ALB 연결 |
| **user-service** | 사용자 관리 | 8080 | DB 연결 |
| **store-service** | 팝업 스토어 관리 | 8080 | DB 연결 |
| **order-service** | 주문 처리 | 8080 | DB + Kafka |
| **payment-service** | 결제 처리 | 8080 | DB + Kafka |
| **qr-service** | QR 코드 생성/검증 | 8080 | DB 연결 |

## 🚀 빠른 시작

### 1. **Global 리소스 배포** (최초 1회)
```bash
# ECR 리포지토리 생성
cd global/ecr
terraform init && terraform apply

# Route53 + ACM 인증서 생성
cd ../route53-acm
terraform init && terraform apply
```

### 2. **개발 환경 배포**
```bash
cd envs/dev

# terraform.tfvars 수정 (ECR URL, 키페어 이름 등)
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 배포 실행
terraform init
terraform plan
terraform apply
```

### 3. **컨테이너 이미지 배포**
```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <ECR_URL>

# 각 서비스 이미지 빌드 및 푸시
for service in api-gateway user-service store-service order-service payment-service qr-service; do
  docker build -t $service .
  docker tag $service:latest <ECR_URL>/goorm-popcorn-dev/$service:latest
  docker push <ECR_URL>/goorm-popcorn-dev/$service:latest
done
```

## 📊 환경별 비용 분석

### **Dev 환경** (~$125/월)
| 서비스 | 스펙 | 비용 |
|--------|------|------|
| RDS PostgreSQL | db.t3.micro | $13 |
| ECS Fargate | 6 tasks × 256 CPU | $45 |
| EC2 Kafka | t3.micro | $8.5 |
| ElastiCache | cache.t4g.micro | $11 |
| ALB + NAT Gateway | - | $48 |

### **Prod 환경** (~$500/월)
| 서비스 | 스펙 | 비용 |
|--------|------|------|
| Aurora PostgreSQL | 3 × db.r6g.large | $200 |
| ECS Fargate | 12 tasks × 512 CPU | $150 |
| EC2 Kafka | 3 × t3.small | $25 |
| ElastiCache | cache.r6g.large | $80 |
| ALB + NAT Gateway | - | $45 |

## 🔧 주요 특징

### **비용 최적화**
- **Dev**: 단일 AZ, 최소 인스턴스 타입
- **Fargate Spot**: 40% 비용 절감 (Prod에서 활용)
- **VPC Endpoints**: NAT Gateway 비용 58% 절감 (향후 적용)

### **고가용성** (Prod)
- **Multi-AZ**: 3개 가용 영역 분산
- **Auto Scaling**: ECS, Aurora 자동 확장
- **Health Check**: ALB, ECS, CloudMap 통합

### **보안**
- **Private Subnets**: 모든 애플리케이션 리소스
- **Secrets Manager**: 데이터베이스 비밀번호 관리
- **Security Groups**: 최소 권한 원칙

### **모니터링**
- **CloudWatch**: 통합 로그 및 메트릭
- **Container Insights**: ECS 클러스터 모니터링
- **Performance Insights**: Aurora 성능 분석

## 🔗 서비스 연결 구조

```
Internet → ALB → API Gateway (ECS)
                      ↓
              Service Discovery (CloudMap)
                      ↓
    ┌─────────────────┼─────────────────┐
    ↓                 ↓                 ↓
User Service    Store Service    Order Service
    ↓                 ↓                 ↓
    └─────────────────┼─────────────────┘
                      ↓
              RDS/Aurora PostgreSQL
                      ↓
                ElastiCache Redis
                      ↓
                  EC2 Kafka
```

## 📋 GitHub Actions (CI/CD)
- PR(`develop`/`main`)에서 `terraform plan` 실행 후 PR 코멘트로 출력
- `develop` 머지 시 dev 환경 `terraform apply`
- `main` 머지 시 prod 환경 `terraform apply`
- Discord Webhook으로 plan/apply 결과 알림 전송

## 📚 문서

- **[개발 환경 구성 가이드](docs/dev-environment-guide.md)**: 전체 개발 환경 구성 방법
- **[EC2 Kafka 모듈 가이드](docs/ec2-kafka-module-guide.md)**: Kafka 클러스터 상세 가이드
- **[각 환경별 README](envs/dev/README.md)**: 환경별 배포 및 운영 가이드

## 🔄 업데이트 로그

### 2024-01-23
- ✅ 스펙 변경: Dev(단일 AZ + RDS), Prod(멀티 AZ + Aurora)
- ✅ Staging 환경 제거
- ✅ RDS PostgreSQL 모듈 추가 (Dev용)
- ✅ Aurora PostgreSQL 모듈 추가 (Prod용)
- ✅ ECS Fargate 모듈 추가 (6개 마이크로서비스)
- ✅ CloudMap 서비스 디스커버리 모듈 추가
- ✅ IAM 역할 모듈 추가
- ✅ 환경별 설정 파일 업데이트
- ✅ 상세 배포 가이드 문서 작성
이미 생성되어 있다면 팀원들은 이 단계 없이 진행합니다.

2) 환경별 backend 설정 파일
- `envs/dev/backend.tf`
- `envs/prod/backend.tf`
- `global/route53-acm/backend.tf`
- `global/ecr/backend.tf`

## 실행 흐름
1) global 스택 (전역 리소스)
```bash
cd global/route53-acm
terraform init
terraform plan
terraform apply
```

```bash
cd global/ecr
terraform init
terraform plan
terraform apply
```

2) dev 스택
```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

3) prod 스택
```bash
cd envs/prod
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## 환경별 차이 (예시 기준)
dev와 prod는 동일한 모듈을 쓰고, 환경별 값만 다르게 적용합니다.

- NAT Gateway 수: dev 1개(또는 미도입) / prod 2개(AZ별)
- Aurora 인스턴스 수: dev 최소 1 / prod 2 이상
- ElastiCache 노드 수: dev 1 / prod 2 이상
- Auto Scaling: dev 최소/비활성화 / prod 활성

## 참고
- `terraform.tfstate`는 커밋하지 않습니다.
- 실행 시 `AWS_PROFILE=terraform` 사용을 권장합니다.
