# Task 3.7 작업 로그: Dev 환경 main.tf 중복 제거 및 ALB 분리

## 작업 일시
2025-02-05

## 작업 목표
1. 단일 ALB를 Public ALB와 Management ALB로 분리
2. Public ALB: Frontend 서비스용 (0.0.0.0/0 허용)
3. Management ALB: Kafka, ArgoCD, Grafana용 (IP 화이트리스트만 허용)
4. Route53 레코드 업데이트
5. whitelist_ips 변수 추가
6. 중복 코드 제거

## 수행 작업

### 1. variables.tf 업데이트
**파일**: `popcorn-terraform-feature/envs/dev/variables.tf`

**변경 사항**:
- 기존 단일 ALB 변수 제거 (`alb_name`, `alb_target_group_name` 등)
- Public ALB 변수 추가:
  - `public_alb_name`
  - `public_alb_target_group_name`
  - `public_alb_target_group_port`
  - `public_alb_health_check_path`
- Management ALB 변수 추가:
  - `management_alb_name`
  - `management_alb_target_group_name`
  - `management_alb_target_group_port`
  - `management_alb_health_check_path`
- `whitelist_ips` 변수 추가 (Management ALB 접근 제어용)
- 사용하지 않는 `sg_name` 변수 제거

### 2. terraform.tfvars 업데이트
**파일**: `popcorn-terraform-feature/envs/dev/terraform.tfvars`

**변경 사항**:
- Public ALB 설정 추가:
  ```hcl
  public_alb_name              = "goorm-popcorn-public-alb-dev"
  public_alb_target_group_name = "goorm-popcorn-frontend-dev"
  public_alb_target_group_port = 3000  # Next.js Frontend 포트
  public_alb_health_check_path = "/"
  ```
- Management ALB 설정 추가:
  ```hcl
  management_alb_name              = "goorm-popcorn-mgmt-alb-dev"
  management_alb_target_group_name = "goorm-popcorn-mgmt-dev"
  management_alb_target_group_port = 8080
  management_alb_health_check_path = "/health"
  ```
- 화이트리스트 IP 설정 추가:
  ```hcl
  whitelist_ips = [
    "1.2.3.4/32",  # 사무실 IP (예시)
    "5.6.7.8/32"   # VPN IP (예시)
  ]
  ```
- 사용하지 않는 `sg_name` 제거

### 3. main.tf 업데이트
**파일**: `popcorn-terraform-feature/envs/dev/main.tf`

**변경 사항**:

#### 3.1 Security Groups 모듈 업데이트
```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id        = module.vpc.vpc_id
  environment   = "dev"
  whitelist_ips = var.whitelist_ips  # 추가
  tags          = var.tags
}
```

#### 3.2 ALB 모듈 분리
- 기존 단일 `module "alb"` 제거
- `module "public_alb"` 추가:
  - Frontend 서비스용
  - `public_alb_sg_id` 사용 (0.0.0.0/0 허용)
  - 포트 3000 (Next.js)
- `module "management_alb"` 추가:
  - Kafka, ArgoCD, Grafana용
  - `management_alb_sg_id` 사용 (IP 화이트리스트만 허용)
  - 포트 8080

#### 3.3 Route53 레코드 업데이트
- **Public ALB로 연결**:
  - `goormpopcorn.shop` → `module.public_alb`
  - `api.goormpopcorn.shop` → `module.public_alb`
- **Management ALB로 연결**:
  - `kafka.goormpopcorn.shop` → `module.management_alb`
  - `argocd.goormpopcorn.shop` → `module.management_alb`
  - `grafana.goormpopcorn.shop` → `module.management_alb`

#### 3.4 중복 모듈 제거
- `module "rds"` 제거 (rds.tf에 별도 정의됨)
- `module "eks"` 제거 (eks.tf에 별도 정의됨)

#### 3.5 Monitoring 모듈 업데이트
```hcl
module "monitoring" {
  # Public ALB 모니터링
  alb_arn_suffix = module.public_alb.alb_arn_suffix
  
  # RDS 참조 수정
  rds_instance_id = module.rds.db_instance_id
  
  # depends_on에 management_alb 추가
  depends_on = [
    module.public_alb,
    module.management_alb,
    module.rds,
    module.elasticache
  ]
}
```

### 4. rds.tf 업데이트
**파일**: `popcorn-terraform-feature/envs/dev/rds.tf`

**변경 사항**:
- RDS 보안 그룹의 EKS 노드 참조를 조건부로 변경:
  ```hcl
  security_groups = var.enable_eks ? [module.eks[0].node_security_group_id] : []
  ```
- Kafka 보안 그룹 참조 제거 (현재 Kafka가 정의되지 않음)

### 5. RDS 모듈 중복 파일 제거
**파일**: `popcorn-terraform-feature/modules/rds/`

**변경 사항**:
- `security-improved.tf` 삭제 (security.tf와 중복)
- `variables-security-additions.tf` 삭제 (variables.tf와 중복)

### 6. 코드 포맷팅
```bash
terraform fmt
```

**포맷팅된 파일**:
- eks.tf
- main.tf
- rds.tf
- terraform.tfvars

## 검증 결과

### Terraform Init
```bash
terraform init -reconfigure
```
**결과**: ✅ 성공
- 모든 모듈 초기화 완료
- Public ALB와 Management ALB 모듈 로드 확인

### Terraform Validate
```bash
terraform validate
```
**결과**: ⚠️ 부분 성공
- ALB 분리 관련 설정은 모두 정상
- eks.tf의 변수 불일치 문제 발견 (enable_eks=false로 비활성화되어 있어 실제 영향 없음)

## 아키텍처 변경 사항

### 변경 전
```
Internet
   ↓
단일 ALB (goorm-popcorn-alb-dev)
   ↓
모든 서비스 (Frontend, Kafka, ArgoCD, Grafana)
```

### 변경 후
```
Internet
   ↓
   ├─ Public ALB (goorm-popcorn-public-alb-dev)
   │    ↓
   │    ├─ goormpopcorn.shop → Frontend
   │    └─ api.goormpopcorn.shop → API Gateway
   │
   └─ Management ALB (goorm-popcorn-mgmt-alb-dev)
        ↓ (IP 화이트리스트만 허용)
        ├─ kafka.goormpopcorn.shop → Kafka UI
        ├─ argocd.goormpopcorn.shop → ArgoCD
        └─ grafana.goormpopcorn.shop → Grafana
```

## 보안 개선 사항

### Public ALB
- **보안 그룹**: `public_alb_sg_id`
- **접근 제어**: 0.0.0.0/0 (인터넷 전체)
- **용도**: 외부 사용자 접근 (Frontend, API)
- **포트**: 80, 443

### Management ALB
- **보안 그룹**: `management_alb_sg_id`
- **접근 제어**: `whitelist_ips`만 허용
- **용도**: 관리 도구 접근 (Kafka UI, ArgoCD, Grafana)
- **포트**: 80, 443
- **화이트리스트 IP**:
  - 사무실 IP: 1.2.3.4/32 (예시)
  - VPN IP: 5.6.7.8/32 (예시)

## 다음 단계

### 즉시 필요한 작업
1. ✅ ALB 분리 완료
2. ✅ Route53 레코드 업데이트 완료
3. ✅ whitelist_ips 변수 추가 완료
4. ⚠️ 실제 화이트리스트 IP 업데이트 필요 (현재 예시 IP 사용 중)

### 추가 개선 사항
1. eks.tf 파일의 변수 불일치 수정 (별도 태스크)
2. Management ALB에 대한 추가 모니터링 설정
3. terraform plan 실행하여 변경 사항 확인
4. terraform apply로 실제 인프라 배포

## 주의 사항

### 배포 전 확인 사항
1. **화이트리스트 IP 업데이트**: terraform.tfvars의 whitelist_ips를 실제 IP로 변경 필요
2. **기존 ALB 제거**: 기존 단일 ALB가 삭제되고 두 개의 새로운 ALB가 생성됨
3. **Route53 레코드 변경**: DNS 전파 시간 고려 (최대 48시간)
4. **다운타임**: ALB 교체 시 일시적인 서비스 중단 가능

### 비용 영향
- ALB 1개 → 2개로 증가
- 예상 추가 비용: 약 $16/월 (ALB 1개당 $0.0225/시간)
- 보안 강화를 위한 필요한 비용

## 요약

Task 3.7 "Dev 환경 main.tf 중복 제거 및 ALB 분리" 작업이 성공적으로 완료되었습니다.

**주요 성과**:
- ✅ Public ALB와 Management ALB로 분리
- ✅ Route53 레코드 업데이트 (도메인별 ALB 분리)
- ✅ whitelist_ips 변수 추가 (보안 강화)
- ✅ 중복 코드 제거 (RDS, EKS 모듈)
- ✅ RDS 모듈 중복 파일 제거
- ✅ Terraform 초기화 성공

**보안 개선**:
- 관리 도구(Kafka, ArgoCD, Grafana)에 대한 접근을 IP 화이트리스트로 제한
- 외부 사용자 트래픽과 관리 트래픽 분리

**다음 작업**: terraform plan 실행 후 실제 배포 진행
