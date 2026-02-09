# Security Groups 모듈

## 개요

이 모듈은 Popcorn 프로젝트의 보안 그룹을 관리합니다. Public ALB, Management ALB, RDS, ElastiCache에 대한 보안 그룹을 생성하고, 최소 권한 원칙에 따라 네트워크 접근을 제어합니다.

## 주요 기능

- **Public ALB 보안 그룹**: 외부 사용자 접근용 (Frontend 서비스)
  - 인터넷(0.0.0.0/0)에서 HTTP(80), HTTPS(443) 접근 허용
  - EKS Node로 모든 포트 아웃바운드 허용

- **Management ALB 보안 그룹**: 관리 도구 접근용 (Kafka, ArgoCD, Grafana)
  - 화이트리스트 IP에서만 HTTP(80), HTTPS(443) 접근 허용
  - EKS Node로 모든 포트 아웃바운드 허용

- **RDS 보안 그룹**: PostgreSQL 데이터베이스
  - EKS Node에서만 PostgreSQL(5432) 접근 허용

- **ElastiCache 보안 그룹**: Valkey 캐시
  - EKS Node에서만 Redis/Valkey(6379) 접근 허용

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet (0.0.0.0/0)                   │
└─────────────────┬───────────────────────┬───────────────────┘
                  │                       │
                  │ HTTP/HTTPS            │ HTTP/HTTPS
                  │ (모든 IP)             │ (화이트리스트 IP만)
                  │                       │
        ┌─────────▼─────────┐   ┌────────▼──────────┐
        │  Public ALB SG    │   │ Management ALB SG │
        │  (Frontend)       │   │ (Kafka/ArgoCD/    │
        │                   │   │  Grafana)         │
        └─────────┬─────────┘   └────────┬──────────┘
                  │                      │
                  │ 모든 포트            │ 모든 포트
                  │                      │
        ┌─────────▼──────────────────────▼──────────┐
        │          EKS Node Security Group          │
        │         (EKS 모듈에서 생성)               │
        └─────────┬──────────────────┬───────────────┘
                  │                  │
                  │ 5432             │ 6379
                  │                  │
        ┌─────────▼─────────┐  ┌────▼──────────┐
        │     RDS SG        │  │ ElastiCache SG│
        │  (PostgreSQL)     │  │   (Valkey)    │
        └───────────────────┘  └───────────────┘
```

## 사용 방법

### 기본 사용 예제

```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  environment = "dev"

  # Management ALB 화이트리스트 IP
  whitelist_ips = [
    "1.2.3.4/32",  # 사무실 IP
    "5.6.7.8/32"   # VPN IP
  ]

  # EKS Node 보안 그룹 ID (EKS 모듈에서 생성)
  eks_node_security_group_id = module.eks.node_security_group_id

  tags = {
    Project     = "popcorn"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Dev 환경 예제

```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  environment = "dev"

  whitelist_ips = [
    "1.2.3.4/32"  # 개발자 IP
  ]

  eks_node_security_group_id = module.eks.node_security_group_id

  tags = {
    Project     = "popcorn"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Prod 환경 예제

```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  environment = "prod"

  whitelist_ips = [
    "1.2.3.4/32",  # 사무실 IP
    "5.6.7.8/32",  # VPN IP
    "9.10.11.12/32" # 운영팀 IP
  ]

  eks_node_security_group_id = module.eks.node_security_group_id

  tags = {
    Project     = "popcorn"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}
```

## 입력 변수

| 변수명 | 타입 | 필수 | 기본값 | 설명 |
|--------|------|------|--------|------|
| `vpc_id` | string | 예 | - | VPC ID |
| `environment` | string | 예 | - | 환경 (dev/prod) |
| `whitelist_ips` | list(string) | 아니오 | [] | Management ALB 화이트리스트 IP 목록 (CIDR 형식) |
| `eks_node_security_group_id` | string | 아니오 | "" | EKS 노드 보안 그룹 ID (EKS 모듈에서 생성) |
| `tags` | map(string) | 아니오 | {} | 리소스 태그 |

### 변수 상세 설명

#### `vpc_id`
- **설명**: 보안 그룹을 생성할 VPC ID
- **예제**: `"vpc-0123456789abcdef0"`

#### `environment`
- **설명**: 환경 구분 (dev 또는 prod)
- **검증**: `dev` 또는 `prod`만 허용
- **예제**: `"dev"`, `"prod"`

#### `whitelist_ips`
- **설명**: Management ALB에 접근 가능한 IP 목록 (CIDR 형식)
- **용도**: Kafka UI, ArgoCD, Grafana 접근 제어
- **예제**: 
  ```hcl
  whitelist_ips = [
    "1.2.3.4/32",      # 단일 IP
    "10.0.0.0/24"      # IP 범위
  ]
  ```

#### `eks_node_security_group_id`
- **설명**: EKS 모듈에서 생성된 노드 보안 그룹 ID
- **용도**: ALB에서 EKS Node로 트래픽 허용 규칙 추가
- **참고**: 이 값이 제공되지 않으면 EKS Node 관련 규칙은 생성되지 않음
- **예제**: `"sg-0123456789abcdef0"`

#### `tags`
- **설명**: 모든 리소스에 적용할 태그
- **예제**:
  ```hcl
  tags = {
    Project     = "popcorn"
    Environment = "dev"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
  ```

## 출력 값

| 출력명 | 타입 | 설명 |
|--------|------|------|
| `public_alb_sg_id` | string | Public ALB 보안 그룹 ID |
| `management_alb_sg_id` | string | Management ALB 보안 그룹 ID |
| `rds_sg_id` | string | RDS 보안 그룹 ID |
| `elasticache_sg_id` | string | ElastiCache 보안 그룹 ID |
| `public_alb_sg_name` | string | Public ALB 보안 그룹 이름 |
| `management_alb_sg_name` | string | Management ALB 보안 그룹 이름 |
| `rds_sg_name` | string | RDS 보안 그룹 이름 |
| `elasticache_sg_name` | string | ElastiCache 보안 그룹 이름 |

### 출력 값 사용 예제

```hcl
# ALB 모듈에서 보안 그룹 참조
module "public_alb" {
  source = "../../modules/alb"

  security_group_ids = [module.security_groups.public_alb_sg_id]
  # ...
}

# RDS 모듈에서 보안 그룹 참조
module "rds" {
  source = "../../modules/rds"

  vpc_security_group_ids = [module.security_groups.rds_sg_id]
  # ...
}

# ElastiCache 모듈에서 보안 그룹 참조
module "elasticache" {
  source = "../../modules/elasticache"

  security_group_ids = [module.security_groups.elasticache_sg_id]
  # ...
}
```

## 보안 그룹 규칙 상세

### Public ALB 보안 그룹

**Ingress 규칙**:
- HTTP (80): 0.0.0.0/0 → Public ALB
- HTTPS (443): 0.0.0.0/0 → Public ALB

**Egress 규칙**:
- 모든 포트 (0-65535): Public ALB → 0.0.0.0/0 (EKS Node로)

### Management ALB 보안 그룹

**Ingress 규칙**:
- HTTP (80): 화이트리스트 IP → Management ALB
- HTTPS (443): 화이트리스트 IP → Management ALB

**Egress 규칙**:
- 모든 포트 (0-65535): Management ALB → 0.0.0.0/0 (EKS Node로)

### RDS 보안 그룹

**Ingress 규칙**:
- PostgreSQL (5432): EKS Node → RDS

**Egress 규칙**:
- 없음 (기본적으로 아웃바운드 트래픽 불필요)

### ElastiCache 보안 그룹

**Ingress 규칙**:
- Redis/Valkey (6379): EKS Node → ElastiCache

**Egress 규칙**:
- 없음 (기본적으로 아웃바운드 트래픽 불필요)

## 보안 고려사항

### 최소 권한 원칙

1. **Public ALB**: 인터넷에서 접근 가능하지만, Frontend 서비스만 노출
2. **Management ALB**: 화이트리스트 IP에서만 접근 가능
3. **RDS/ElastiCache**: EKS Node에서만 접근 가능
4. **EKS Node**: ALB에서만 인바운드 트래픽 허용

### 화이트리스트 관리

Management ALB 화이트리스트 IP는 다음과 같이 관리합니다:

```hcl
# terraform.tfvars
management_whitelist_ips = [
  "1.2.3.4/32",      # 사무실 IP
  "5.6.7.8/32",      # VPN IP
  "9.10.11.12/32"    # 운영팀 IP
]
```

**주의사항**:
- IP 변경 시 terraform.tfvars 파일 업데이트 필요
- CIDR 형식으로 작성 (예: `1.2.3.4/32`)
- 단일 IP는 `/32` 사용
- IP 범위는 적절한 CIDR 블록 사용 (예: `/24`)

### 보안 그룹 규칙 변경

보안 그룹 규칙을 변경할 때는 다음 절차를 따릅니다:

1. **계획 단계**: `terraform plan`으로 변경 사항 검토
2. **테스트**: Dev 환경에서 먼저 테스트
3. **적용**: `terraform apply`로 변경 사항 적용
4. **검증**: 애플리케이션 연결 테스트

## 트러블슈팅

### 문제: Management ALB에 접근할 수 없음

**원인**: 화이트리스트 IP에 현재 IP가 포함되지 않음

**해결**:
1. 현재 IP 확인: `curl ifconfig.me`
2. `terraform.tfvars`에 IP 추가
3. `terraform apply` 실행

### 문제: RDS 연결 실패

**원인**: EKS Node 보안 그룹 ID가 올바르지 않음

**해결**:
1. EKS 모듈 출력 확인: `terraform output -module=eks`
2. `eks_node_security_group_id` 변수 확인
3. `terraform apply` 재실행

### 문제: 보안 그룹 규칙 충돌

**원인**: 기존 보안 그룹 규칙과 충돌

**해결**:
1. AWS Console에서 보안 그룹 확인
2. 충돌하는 규칙 제거
3. `terraform apply` 재실행

## 모듈 의존성

이 모듈은 다음 모듈과 함께 사용됩니다:

- **VPC 모듈**: VPC ID 제공
- **EKS 모듈**: EKS Node 보안 그룹 ID 제공
- **ALB 모듈**: ALB 보안 그룹 ID 사용
- **RDS 모듈**: RDS 보안 그룹 ID 사용
- **ElastiCache 모듈**: ElastiCache 보안 그룹 ID 사용

## 참고 자료

- [AWS Security Groups 문서](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Terraform aws_security_group 리소스](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)
- [Terraform aws_security_group_rule 리소스](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule)

## 버전 히스토리

- **v1.0.0** (2025-02-05): 초기 버전
  - Public ALB, Management ALB, RDS, ElastiCache 보안 그룹 생성
  - 화이트리스트 IP 기반 접근 제어
  - EKS 기반 아키텍처 지원
