# Task 8.1 & 8.2: Terraform 검증

## 작업 일시
2026-02-09

## 작업 내용

Dev 및 Prod 환경의 Terraform 코드를 검증하여 배포 전 정확성을 확인합니다.

## 발견된 문제

### 문제 1: EKS 모듈 Provider 설정과 Count 충돌

**증상**:
```
Error: Module is incompatible with count, for_each, and depends_on

The module at module.eks is a legacy module which contains its own local provider
configurations, and so calls to it may not use the count, for_each, or depends_on arguments.
```

**원인**:
- Task 6.1에서 EKS 모듈에 `providers.tf` 파일을 추가함
- Terraform에서는 모듈 내부에 provider 설정이 있으면 `count`, `for_each`, `depends_on`을 사용할 수 없음
- Dev 환경의 `eks.tf`에서 `count = var.enable_eks ? 1 : 0`를 사용하여 조건부 생성 시도

**해결**:
- Dev 환경의 `eks.tf`에서 EKS 모듈 호출을 주석 처리
- EKS는 "6-12개월 후 ECS에서 EKS로 전환을 위한 설정"이므로 현재는 비활성화 상태
- 향후 EKS 활성화 시 provider 설정을 상위 레벨로 이동 필요

### 문제 2: 환경 구조 불일치

**증상**:
```
Error: Reference to undeclared module
Error: Unsupported attribute
Error: Reference to undeclared local value
```

**원인**:
- 현재 Dev 환경은 ECS 기반 인프라
- 스펙은 EKS 기반 리팩토링
- 두 구조가 혼재되어 있음

**영향받는 리소스**:
1. **모듈 참조 오류**:
   - `module.alb` → `module.public_alb`, `module.management_alb`로 분리됨
   - `module.ec2_kafka` → 현재 환경에 없음
   - `module.ecs` → EKS로 전환 예정
   - `module.cloudmap` → 현재 환경에 없음

2. **Security Groups 출력 오류**:
   - `cache_sg_id` → `elasticache_sg_id`로 변경됨

3. **RDS 출력 오류**:
   - `endpoint`, `port`, `database_name`, `master_password_secret_arn` → 모듈 출력 이름 불일치

4. **Local 값 오류**:
   - `local.name_prefix`, `local.environment`, `local.common_tags` → 정의되지 않음

## 현재 상황 분석

### 기존 환경 (ECS 기반)
```
popcorn-terraform-feature/envs/dev/
├── main.tf              # ECS 클러스터, EC2 Kafka 등
├── rds.tf               # RDS 설정
├── eks.tf               # EKS 준비 (비활성화)
├── outputs.tf           # ECS 관련 출력
└── ...
```

### 스펙 목표 (EKS 기반)
```
popcorn-terraform-feature/envs/dev/
├── main.tf              # VPC, EKS, RDS, ElastiCache, ALB, Security Groups, IAM, Monitoring
├── variables.tf         # 환경 변수
├── terraform.tfvars     # 변수 값
├── backend.tf           # S3 백엔드
└── outputs.tf           # 모든 리소스 출력
```

## 해결 방안

### 옵션 1: 기존 환경 유지 + 스펙 환경 분리 (권장)

**장점**:
- 기존 ECS 환경 영향 없음
- 스펙대로 새로운 EKS 환경 구축 가능
- 점진적 마이그레이션 가능

**단점**:
- 두 환경 관리 필요
- 리소스 중복 가능

**구현**:
```bash
# 새로운 디렉터리 생성
envs/dev-eks/          # 스펙대로 EKS 기반 환경
envs/dev/              # 기존 ECS 기반 환경 유지
```

### 옵션 2: 기존 환경을 스펙에 맞게 전면 리팩토링

**장점**:
- 단일 환경 관리
- 스펙과 완전히 일치

**단점**:
- 기존 인프라 영향 큼
- 다운타임 발생 가능
- 롤백 어려움

**구현**:
```bash
# 기존 파일 백업
cp -r envs/dev envs/dev.backup

# 스펙대로 전면 재작성
envs/dev/main.tf       # 완전히 새로 작성
envs/dev/outputs.tf    # 완전히 새로 작성
...
```

### 옵션 3: 점진적 마이그레이션

**장점**:
- 단계별 전환 가능
- 리스크 최소화

**단점**:
- 시간 소요
- 중간 상태 관리 복잡

**구현**:
1. 현재 ECS 환경 유지
2. EKS 클러스터 추가 (병렬 운영)
3. 서비스 하나씩 EKS로 이전
4. ECS 클러스터 제거

## 권장 사항

**현재 상황을 고려한 권장 사항**:

1. **스펙 목적 확인**:
   - 이 스펙은 "새로운 EKS 기반 인프라 구축"인가?
   - 아니면 "기존 ECS 환경을 EKS로 마이그레이션"인가?

2. **옵션 1 선택 (새로운 환경 구축)**:
   - `envs/dev-eks/` 디렉터리 생성
   - 스펙대로 완전히 새로운 환경 구축
   - 기존 `envs/dev/` 환경은 유지

3. **다음 단계**:
   - 사용자에게 의사 결정 요청
   - 선택된 옵션에 따라 작업 진행

## 임시 해결 (검증 계속 진행)

현재 검증을 계속하기 위해 다음 작업을 수행합니다:

### 1. EKS 모듈 주석 처리 완료
- ✅ Dev 환경의 `eks.tf`에서 EKS 모듈 주석 처리
- ✅ Provider 충돌 문제 해결

### 2. 나머지 오류는 스펙 구현 시 해결
- Security Groups 출력 이름 수정
- RDS 출력 이름 수정
- Local 값 정의
- 모듈 참조 수정

## 다음 단계

### 사용자 의사 결정 필요

**질문 1**: 이 스펙의 목적은 무엇인가요?
- A. 새로운 EKS 기반 인프라 구축 (기존 ECS 환경과 별도)
- B. 기존 ECS 환경을 EKS로 전면 마이그레이션
- C. 기존 ECS 환경에 EKS를 추가하여 점진적 마이그레이션

**질문 2**: 기존 ECS 환경은 어떻게 할까요?
- A. 유지 (병렬 운영)
- B. 제거 (EKS로 완전 전환)
- C. 점진적 제거 (서비스별 이전)

### 권장 진행 방향

**단기 (현재 스펙 완료)**:
1. `envs/dev-eks/` 디렉터리 생성
2. 스펙대로 EKS 기반 환경 구축
3. 기존 `envs/dev/` 환경 유지

**중기 (마이그레이션)**:
1. EKS 환경 안정화
2. 서비스별 EKS 이전 계획 수립
3. 점진적 마이그레이션 실행

**장기 (통합)**:
1. 모든 서비스 EKS 이전 완료
2. ECS 환경 제거
3. `envs/dev-eks/` → `envs/dev/`로 통합

## 참고사항

### Terraform Provider in Module 제약사항

**문제**:
- 모듈 내부에 provider 설정이 있으면 `count`, `for_each`, `depends_on` 사용 불가

**해결 방법**:
1. **Provider Configuration 제거** (권장):
   ```hcl
   # modules/eks/providers.tf 삭제
   # 상위 레벨에서 provider 전달
   ```

2. **Required Providers만 선언**:
   ```hcl
   # modules/eks/versions.tf
   terraform {
     required_providers {
       kubernetes = {
         source  = "hashicorp/kubernetes"
         version = "~> 2.0"
       }
       helm = {
         source  = "hashicorp/helm"
         version = "~> 2.0"
       }
     }
   }
   ```

3. **상위 레벨에서 Provider 설정**:
   ```hcl
   # envs/dev/providers.tf
   provider "kubernetes" {
     host = module.eks.cluster_endpoint
     ...
   }
   
   provider "helm" {
     kubernetes {
       host = module.eks.cluster_endpoint
       ...
     }
   }
   ```

### 환경 분리 전략

**디렉터리 구조**:
```
envs/
├── dev/              # 기존 ECS 환경
│   ├── main.tf
│   ├── rds.tf
│   └── ...
├── dev-eks/          # 새로운 EKS 환경 (스펙)
│   ├── main.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── backend.tf
│   └── outputs.tf
└── prod/             # 프로덕션 환경
    └── ...
```

**Backend 설정**:
```hcl
# envs/dev/backend.tf
terraform {
  backend "s3" {
    bucket = "goorm-popcorn-tfstate"
    key    = "dev/terraform.tfstate"        # ECS 환경
    ...
  }
}

# envs/dev-eks/backend.tf
terraform {
  backend "s3" {
    bucket = "goorm-popcorn-tfstate"
    key    = "dev-eks/terraform.tfstate"    # EKS 환경
    ...
  }
}
```

## 결론

Task 8.1 & 8.2 검증 중 다음 문제를 발견했습니다:

1. ✅ **EKS 모듈 Provider 충돌**: 해결 완료 (주석 처리)
2. ⚠️ **환경 구조 불일치**: 사용자 의사 결정 필요

**다음 작업**:
- 사용자에게 스펙 목적 및 진행 방향 확인
- 선택된 옵션에 따라 작업 계속 진행

**임시 상태**:
- Dev 환경 terraform init 성공
- Dev 환경 terraform validate 실패 (환경 구조 불일치)
- Prod 환경 검증 대기 중
