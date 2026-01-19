# Goorm Popcorn - Terraform Infrastructure

이 디렉토리는 Goorm Popcorn 팝업 이벤트 이커머스 플랫폼의 AWS 인프라를 관리하는 Terraform 코드를 포함합니다.

## 📋 주요 문서

### 🚀 배포 관련
- **[배포 가이드](./DEPLOYMENT.md)** - 단계별 배포 방법 및 설정
- **[환경별 비교](./ENVIRONMENT_COMPARISON.md)** - Dev/Staging/Prod 환경 차이점 및 비용

### ⚙️ 환경별 설정 파일
- **[Dev 환경 설정](./environments/dev/terraform.tfvars.example)** - 개발 환경 변수 (~$150/월)
- **[Staging 환경 설정](./environments/staging/terraform.tfvars.example)** - 스테이징 환경 변수 (~$400/월)
- **[Production 환경 설정](./environments/prod/terraform.tfvars.example)** - 프로덕션 환경 변수 (~$765/월)

### 🏗️ 글로벌 리소스 설정
- **[ECR 설정](./global/ecr/variables.tf)** - Container Registry 설정
- **[Route53 설정](./global/route53/variables.tf)** - DNS 및 SSL 인증서 설정

## 🏛️ 아키텍처 개요

- **컴퓨팅**: ECS Fargate (6개 마이크로서비스 + API Gateway)
- **네트워크**: VPC 3-Tier 아키텍처 (Public/Private-App/Private-Data)
- **데이터베이스**: Aurora PostgreSQL + ElastiCache Redis
- **메시징**: MSK Serverless
- **서비스 검색**: AWS Cloud Map
- **보안**: Secrets Manager, VPC Endpoints
- **모니터링**: CloudWatch

## 📁 디렉토리 구조

```
terraform/
├── 📖 DEPLOYMENT.md              # 배포 가이드
├── 📊 ENVIRONMENT_COMPARISON.md  # 환경별 비교
├── environments/                 # 환경별 설정
│   ├── dev/                     # 개발 환경 (~$150/월)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
│   ├── staging/                 # 스테이징 환경 (~$400/월)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
│   └── prod/                    # 프로덕션 환경 (~$765/월)
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars.example
├── modules/                     # 재사용 가능한 모듈
│   ├── vpc/                    # VPC 및 네트워킹
│   ├── ecs/                    # ECS 클러스터 및 서비스
│   ├── rds/                    # Aurora PostgreSQL
│   ├── elasticache/            # ElastiCache Redis
│   ├── msk/                    # MSK Serverless
│   ├── alb/                    # Application Load Balancer
│   ├── cloudmap/               # AWS Cloud Map
│   ├── security-groups/        # Security Groups
│   └── iam/                    # IAM 역할 및 정책
└── global/                     # 글로벌 리소스
    ├── ecr/                    # Container Registry
    └── route53/                # DNS 및 SSL 인증서
```

## 🚀 빠른 시작

### 1. 환경별 배포

```bash
# 개발 환경 (최소 비용)
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform apply

# 스테이징 환경 (QA 테스트)
cd terraform/environments/staging
cp terraform.tfvars.example terraform.tfvars
terraform apply

# 프로덕션 환경 (실제 서비스)
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
terraform apply
```

### 2. 주요 환경 변수

각 환경의 `terraform.tfvars` 파일에서 다음 값들을 설정해야 합니다:

```hcl
# 필수 설정
certificate_arn = "arn:aws:acm:..."        # SSL 인증서 ARN
ecr_repository_url = "123456789012.dkr..."  # ECR 레포지토리 URL

# 환경별 차별화 설정
vpc_cidr = "10.0.0.0/16"                   # VPC CIDR (환경별 다름)
aurora_instance_count = 2                   # DB 인스턴스 수
elasticache_node_type = "cache.t4g.small"  # 캐시 인스턴스 타입
```

## 💰 환경별 비용

| 환경 | 월 비용 | 주요 특징 |
|------|---------|-----------|
| **Dev** | **~$150** | 단일 AZ, 최소 인스턴스, Auto Scaling 비활성화 |
| **Staging** | **~$400** | Multi-AZ, 중간 사양, 제한적 Auto Scaling |
| **Production** | **~$765** | Multi-AZ, 고사양, 완전 Auto Scaling |

## 🔧 주요 특징

- **모듈화**: 재사용 가능한 모듈 구조
- **환경 분리**: dev/staging/prod 환경 독립 관리
- **보안**: 최소 권한 원칙, VPC Endpoints
- **확장성**: Auto Scaling, Multi-AZ
- **비용 최적화**: Fargate Spot, 환경별 차별화

## 📚 추가 정보

- **상세 배포 방법**: [DEPLOYMENT.md](./DEPLOYMENT.md) 참조
- **환경별 상세 비교**: [ENVIRONMENT_COMPARISON.md](./ENVIRONMENT_COMPARISON.md) 참조
- **문제 해결**: [DEPLOYMENT.md](./DEPLOYMENT.md#문제-해결) 섹션 참조

## 🆘 지원

문의사항이나 이슈가 있으면 다음 채널로 연락하세요:
- Infrastructure Team: infra@goormpopcorn.shop
- Slack: #infrastructure
- 긴급상황: PagerDuty