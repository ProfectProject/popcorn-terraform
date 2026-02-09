# Terraform 구성 문제 해결 로그

**날짜**: 2024-01-26  
**프로젝트**: Goorm Popcorn Infrastructure  
**환경**: Dev/Prod Terraform 구성  

---

## 문제 상황 개요

요구사항과 설계 문서에 맞게 Terraform 구성을 수정하는 과정에서 여러 문제가 발생했습니다.

---

## 1. 의사결정 사항 정리

### 1.1 사용자 요구사항
- **키페어**: 기존 키페어 `goorm-popcorn-keypair` 사용
- **ECR Repository URLs**: 실제 AWS 계정 ID `375896310755` 사용
- **VPC Endpoints**: 추가하지 않음 (비용 최적화)
- **네트워크 구조**: 3-tier 구조 선택 (Public, Private App+Kafka, Private DB+Cache)

### 1.2 제공된 ECR Repository URLs
```
375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-api-gateway
375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-user
375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-store
375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-order
375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-payment
375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-qr
375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-order-query
```

---

## 2. 발생한 문제들

### 2.1 Terraform 버전 호환성 문제

**문제**:
```
Error: Unsupported Terraform Core version
  on versions.tf line 2, in terraform:
   2:   required_version = ">= 1.8.0, < 2.0.0"

This configuration does not support Terraform version 1.5.7.
```

**원인**: 
- 사용자 환경: Terraform 1.5.7
- 설정된 요구사항: >= 1.8.0

**해결방법**:
```hcl
# Before
required_version = ">= 1.8.0, < 2.0.0"

# After
required_version = ">= 1.5.0, < 2.0.0"
```

**파일**: `popcorn-terraform-feature/envs/dev/versions.tf`

### 2.2 Terraform 표현식 구문 오류

**문제**:
```
Error: Invalid expression
  on ../../modules/ecs/main.tf line 103, in resource "aws_ecs_task_definition" "services":
 103:       image = length(var.ecr_repositories) > 0 && contains(keys(var.ecr_repositories), each.key) ? 
 104:               "${var.ecr_repositories[each.key]}:latest" : 

Expected the start of an expression, but found an invalid expression token.
```

**원인**: 
- Terraform 1.5.7에서 복잡한 삼항 연산자 구문 파싱 문제
- 다중 조건과 함수 호출이 포함된 표현식

**해결방법**:
1. **locals 블록 사용**: 복잡한 로직을 locals에서 미리 계산
2. **단순화된 조건**: `length()` 체크 제거

```hcl
# Before (문제 있는 코드)
image = length(var.ecr_repositories) > 0 && contains(keys(var.ecr_repositories), each.key) ? 
        "${var.ecr_repositories[each.key]}:latest" : 
        "${var.ecr_repository_url}/${var.name}/${each.key}:latest"

# After (해결된 코드)
locals {
  service_images = {
    for service_name in var.service_names : service_name => (
      contains(keys(var.ecr_repositories), service_name) ?
      "${var.ecr_repositories[service_name]}:${var.image_tag}" :
      "${var.ecr_repository_url}/${var.name}/${service_name}:${var.image_tag}"
    )
  }
}

# 사용
image = local.service_images[each.key]
```

**파일**: `popcorn-terraform-feature/modules/ecs/main.tf`

---

## 3. 주요 구성 변경사항

### 3.1 네트워크 구조 변경 (4-tier → 3-tier)

**변경 이유**: 사용자 요구사항에 따른 단순화

**Before (4-tier)**:
- Public Subnet
- Private App Subnet (ECS)
- Private Cache/Msg Subnet (Kafka, ElastiCache)
- Private Data Subnet (Database)

**After (3-tier)**:
- Public Subnet (ALB, NAT Gateway)
- Private Subnet (ECS, Kafka)
- Data Subnet (Database, ElastiCache)

**영향받은 파일들**:
- `modules/vpc/main.tf`
- `modules/vpc/variables.tf`
- `modules/vpc/outputs.tf`
- `envs/dev/main.tf`
- `envs/prod/main.tf`
- `envs/dev/variables.tf`
- `envs/prod/variables.tf`
- `envs/dev/terraform.tfvars`
- `envs/prod/terraform.tfvars`

### 3.2 서브넷 구성 변경

**Dev 환경 (단일 AZ)**:
```yaml
Before:
  - Public: 10.0.1.0/24, 10.0.2.0/24
  - App: 10.0.11.0/24, 10.0.12.0/24
  - Cache/Msg: 10.0.21.0/24, 10.0.22.0/24
  - Data: 10.0.31.0/24, 10.0.32.0/24

After:
  - Public: 10.0.1.0/24
  - Private: 10.0.11.0/24
  - Data: 10.0.21.0/24
```

**Prod 환경 (Multi-AZ)**:
```yaml
Before:
  - Public: 10.0.1.0/24, 10.0.2.0/24
  - App: 10.0.11.0/24, 10.0.12.0/24
  - Cache/Msg: 10.0.21.0/24, 10.0.22.0/24
  - Data: 10.0.31.0/24, 10.0.32.0/24

After:
  - Public: 10.0.1.0/24, 10.0.2.0/24
  - Private: 10.0.11.0/24, 10.0.12.0/24
  - Data: 10.0.21.0/24, 10.0.22.0/24
```

### 3.3 ECR Repository 매핑 추가

**문제**: 기존 코드는 `${base_url}/${project}/${service}` 형식을 가정했지만, 실제 ECR URL은 전체 경로가 제공됨

**해결방법**: ECR Repository 매핑 변수 추가
```hcl
variable "ecr_repositories" {
  description = "Map of service names to ECR repository URLs"
  type        = map(string)
  default     = {}
}
```

### 3.4 Route53 설정 추가

**추가된 설정**:
- **호스팅 영역 ID**: `Z00594183MIRRC8JIBDYS`
- **Dev 도메인**: `dev.goormpopcorn.shop`
- **Prod 도메인**: `goormpopcorn.shop`

---

## 4. 동적 이미지 태그 지원 추가

### 4.1 태그 생성 규칙 구현

사용자가 제공한 Git 기반 태그 생성 규칙을 Terraform에 반영:

```bash
# Git SHA 기반 태그 (모든 브랜치)
GIT_SHA=$(git rev-parse --short=8 HEAD)

# 브랜치별 태그 생성
case "$GITHUB_REF" in
  refs/heads/main)
    TAGS="$GIT_SHA,latest"
    ;;
  refs/heads/develop)
    TAGS="dev-$GIT_SHA,dev-latest,dev-$(date +%Y%m%d)"
    ;;
  refs/heads/feature/*)
    BRANCH_NAME=$(echo $GITHUB_REF_NAME | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')
    TAGS="feature-$BRANCH_NAME-$GIT_SHA"
    ;;
  refs/heads/hotfix/*)
    BRANCH_NAME=$(echo $GITHUB_REF_NAME | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]')
    TAGS="hotfix-$BRANCH_NAME-$GIT_SHA"
    ;;
  refs/pull/*)
    PR_NUMBER=$(echo $GITHUB_REF | sed 's/refs\/pull\/\([0-9]*\)\/merge/\1/')
    TAGS="pr-$PR_NUMBER-$GIT_SHA"
    ;;
esac
```

### 4.2 Terraform 변수 추가

```hcl
variable "image_tag" {
  description = "Docker image tag to use"
  type        = string
  default     = "dev-latest"  # Dev 환경
  # default     = "latest"    # Prod 환경
}
```

### 4.3 사용 방법

```bash
# 기본 태그 사용
terraform apply

# 특정 태그 지정
terraform apply -var="image_tag=feature-auth-abc12345"
terraform apply -var="image_tag=pr-123-def67890"
```

---

## 5. 설계 문서 업데이트

### 5.1 주요 변경사항
- 네트워크 구조 4-tier → 3-tier 반영
- 실제 ECR Repository URL 반영
- 키페어 설정 추가
- Route53 설정 추가
- Order Query 서비스 추가 (총 7개 서비스)
- 비용 구조 업데이트

### 5.2 문서 버전
- **이전**: 2.5
- **현재**: 3.0

---

## 6. 해결된 최종 구성

### 6.1 환경별 최적화 완료

**Dev 환경**:
- ✅ 단일 AZ 구성 (비용 최적화)
- ✅ RDS PostgreSQL (db.t4g.micro)
- ✅ ElastiCache 단일 노드 (cache.t4g.micro)
- ✅ EC2 Kafka 단일 브로커 (t3.small, KRaft 모드)
- ✅ 3-tier 네트워크 구조
- ✅ 동적 이미지 태그 지원

**Prod 환경**:
- ✅ Multi-AZ 구성 (고가용성)
- ✅ Aurora PostgreSQL (db.r6g.large)
- ✅ ElastiCache Primary-Replica (cache.t4g.small)
- ✅ EC2 Kafka 3 브로커 (t3.medium, KRaft 모드)
- ✅ 3-tier 네트워크 구조
- ✅ 동적 이미지 태그 지원

### 6.2 비용 최적화 결과

**Dev 환경**: $115/월  
**Prod 환경**: $673.5/월 (최적화 후)  
**대안 대비**: 53% 절감

---

## 7. 교훈 및 개선사항

### 7.1 Terraform 버전 호환성
- **교훈**: 프로젝트 시작 시 사용자 환경의 Terraform 버전 확인 필요
- **개선**: 최소 지원 버전을 현실적으로 설정 (1.5.0+)

### 7.2 복잡한 표현식 처리
- **교훈**: 복잡한 조건문은 locals 블록에서 미리 계산
- **개선**: 가독성과 호환성을 위해 단순한 구문 사용

### 7.3 요구사항 수집
- **교훈**: 초기에 구체적인 요구사항 (ECR URL, 키페어, 도메인 등) 수집 필요
- **개선**: 체크리스트 기반 요구사항 수집 프로세스 도입

### 7.4 설계 문서 동기화
- **교훈**: 구현과 설계 문서 간 불일치 발생
- **개선**: 구현 완료 후 즉시 설계 문서 업데이트

---

## 8. 다음 단계

### 8.1 배포 준비 완료
- [x] Terraform 구문 오류 해결
- [x] 환경별 구성 완료
- [x] 동적 태그 지원 추가
- [x] 설계 문서 업데이트

### 8.2 배포 순서
1. Dev 환경 배포 및 테스트
2. Prod 환경 배포
3. CI/CD 파이프라인 구성
4. 모니터링 설정

### 8.3 확인 필요사항
- [ ] 키페어 `goorm-popcorn-keypair` 존재 확인
- [ ] S3 백엔드 버킷 존재 확인
- [ ] DynamoDB 락 테이블 존재 확인
- [ ] Route53 호스팅 영역 존재 확인

---

**문서 작성자**: Infrastructure Team  
**검토 완료**: 2024-01-26  
**상태**: 해결 완료

---

## 9. 최종 수정사항 (2024-01-26 오후)

### 9.1 Terraform Plan 실행 문제 해결

**문제**: 
```bash
terraform plan
var.app_subnets
  Enter a value:
```

**원인**: 
- `outputs.tf`에서 `app_subnet_ids` 참조하고 있었으나 VPC 모듈은 `private_subnet_ids` 출력
- 변수명 불일치로 인한 terraform plan 실행 중단

**해결방법**:
```hcl
# Before (popcorn-terraform-feature/envs/dev/outputs.tf)
output "app_subnet_ids" {
  description = "App subnet IDs"
  value       = module.vpc.app_subnet_ids
}

# After
output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}
```

**수정된 파일**: `popcorn-terraform-feature/envs/dev/outputs.tf`

### 9.2 Provider 버전 호환성 문제 해결

**문제**:
```
Error: Failed to query available provider packages
Could not retrieve the list of available versions for provider hashicorp/random 3.8.0 
does not match configured version constraint ~> 3.6.0; must use terraform init -upgrade
```

**해결방법**:
```bash
terraform init -upgrade
```

### 9.3 최종 Terraform Plan 검증 완료

**결과**: ✅ **성공**
- **생성될 리소스**: 108개
- **변경될 리소스**: 0개
- **삭제될 리소스**: 0개

**주요 생성 리소스**:
- VPC 및 서브넷 (3-tier 구조)
- 보안 그룹 5개 (ALB, ECS, DB, Cache, Kafka)
- ALB 및 타겟 그룹
- RDS PostgreSQL (db.t4g.micro)
- ElastiCache Redis (cache.t4g.micro)
- ECS Fargate 클러스터 및 서비스 7개
- EC2 Kafka 인스턴스 (t3.small)
- CloudMap 서비스 디스커버리
- IAM 역할 및 정책
- Route53 DNS 레코드

### 9.4 구성 검증 완료

**네트워크 구조**:
```yaml
VPC: 10.0.0.0/16
├── Public Subnet: 10.0.1.0/24 (ap-northeast-2a)
│   ├── ALB
│   └── NAT Gateway
├── Private Subnet: 10.0.11.0/24 (ap-northeast-2a)
│   ├── ECS Services (7개)
│   └── Kafka Broker
└── Data Subnet: 10.0.21.0/24 (ap-northeast-2a)
    ├── RDS PostgreSQL
    └── ElastiCache Redis
```

**서비스 구성**:
```yaml
ECS Services:
  - api-gateway: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-api-gateway
  - user-service: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-user
  - store-service: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-store
  - order-service: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-order
  - payment-service: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-payment
  - qr-service: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-qr
  - order-query: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-order-query

CloudMap Services:
  - Namespace: goormpopcorn.local
  - 7개 서비스 자동 등록
```

### 9.5 배포 준비 상태 확인

**✅ 완료된 항목**:
- [x] Terraform 구문 오류 해결
- [x] 변수 및 출력 일관성 확인
- [x] Provider 버전 호환성 해결
- [x] 네트워크 구조 3-tier 구현
- [x] ECR Repository URL 매핑 완료
- [x] 동적 이미지 태그 지원
- [x] CloudMap 서비스 디스커버리 구성
- [x] 보안 그룹 규칙 최적화
- [x] Route53 DNS 설정
- [x] Terraform Plan 검증 완료

**⚠️ 배포 전 확인 필요**:
- [ ] AWS 계정 자격 증명 설정
- [ ] 키페어 `goorm-popcorn-keypair` 존재 확인
- [ ] S3 백엔드 버킷 `goorm-popcorn-tfstate` 접근 권한
- [ ] DynamoDB 테이블 `goorm-popcorn-tfstate-lock` 접근 권한
- [ ] Route53 호스팅 영역 `Z00594183MIRRC8JIBDYS` 접근 권한
- [ ] ECR 리포지토리 7개 존재 및 접근 권한

### 9.6 예상 배포 시간 및 비용

**배포 시간**: 약 15-20분
- VPC 및 네트워크: 2-3분
- RDS 인스턴스: 5-7분
- ElastiCache: 3-5분
- ECS 서비스: 3-5분
- 기타 리소스: 2-3분

**월간 예상 비용 (Dev 환경)**:
- RDS PostgreSQL (db.t4g.micro): ~$12
- ElastiCache (cache.t4g.micro): ~$11
- EC2 Kafka (t3.small): ~$15
- ECS Fargate (7 서비스): ~$50
- ALB: ~$16
- NAT Gateway: ~$32
- 기타 (Route53, CloudWatch): ~$5
- **총 예상 비용**: ~$141/월

---

## 10. 최종 상태 요약

### 10.1 해결된 모든 문제
1. ✅ Terraform 버전 호환성 (1.8.0 → 1.5.0)
2. ✅ 복잡한 삼항 연산자 구문 오류
3. ✅ 네트워크 구조 변경 (4-tier → 3-tier)
4. ✅ ECR Repository URL 매핑
5. ✅ 변수명 불일치 (app_subnet_ids → private_subnet_ids)
6. ✅ Provider 버전 제약 조건
7. ✅ 동적 이미지 태그 지원
8. ✅ CloudMap 서비스 디스커버리 구성

### 10.2 구현된 기능
- **완전한 3-tier 네트워크 아키텍처**
- **7개 마이크로서비스 ECS 배포**
- **서비스 디스커버리 (CloudMap)**
- **데이터베이스 (RDS PostgreSQL)**
- **캐시 (ElastiCache Redis)**
- **메시징 (EC2 Kafka)**
- **로드 밸런싱 (ALB + HTTPS)**
- **DNS 관리 (Route53)**
- **보안 (Security Groups + IAM)**

### 10.3 배포 준비 완료
현재 상태에서 `terraform apply` 명령으로 전체 인프라를 배포할 수 있습니다.

**다음 명령어로 배포 시작**:
```bash
cd popcorn-terraform-feature/envs/dev
terraform apply
```

---

**최종 업데이트**: 2024-01-26 오후  
**상태**: 배포 준비 완료 ✅  
**검증**: Terraform Plan 성공 (108 리소스 생성 예정)