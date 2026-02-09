# Task 5.1 & 5.2: Route53 서브도메인 설정

## 작업 일시
2026-02-09

## 작업 내용

Dev 및 Prod 환경에 Route53 레코드를 추가하여 Management ALB에 대한 서브도메인을 설정했습니다.

## 상태 확인

### Task 5.1: Dev 환경 Route53 레코드
**파일**: `popcorn-terraform-feature/envs/dev/main.tf`

**결과**: ✅ 이미 완료됨

**추가된 레코드**:
```hcl
# Route53 레코드 - Management ALB (관리 도구)
resource "aws_route53_record" "kafka" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "kafka.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "argocd" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "argocd.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "grafana.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

### Task 5.2: Prod 환경 Route53 레코드
**파일**: `popcorn-terraform-feature/envs/prod/main.tf`

**결과**: ✅ 이미 완료됨

**추가된 레코드**:
```hcl
# Route53 레코드 - Management ALB (관리 도구)
resource "aws_route53_record" "kafka" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "kafka.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "argocd" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "argocd.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "grafana.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

## 서브도메인 목록

### Dev 환경
- ✅ `kafka.goormpopcorn.shop` → Management ALB
- ✅ `argocd.goormpopcorn.shop` → Management ALB
- ✅ `grafana.goormpopcorn.shop` → Management ALB

### Prod 환경
- ✅ `kafka.goormpopcorn.shop` → Management ALB
- ✅ `argocd.goormpopcorn.shop` → Management ALB
- ✅ `grafana.goormpopcorn.shop` → Management ALB

## 레코드 설정 상세

### 레코드 타입
- **타입**: A 레코드 (Alias)
- **대상**: Management ALB DNS 이름
- **헬스체크**: `evaluate_target_health = true`

### Zone ID 참조
- **소스**: `data.terraform_remote_state.global_route53_acm.outputs.zone_id`
- **설명**: Global Route53 & ACM 상태에서 Zone ID를 참조

### ALB 참조
- **DNS 이름**: `module.management_alb.alb_dns_name`
- **Zone ID**: `module.management_alb.alb_zone_id`

## 보안 설정

### Management ALB 접근 제어
- **보안 그룹**: `module.security_groups.management_alb_sg_id`
- **Ingress 규칙**: 
  - HTTP (80): Whitelist IPs만
  - HTTPS (443): Whitelist IPs만
- **화이트리스트 IP**: `var.whitelist_ips`에서 관리

### 환경별 화이트리스트

**Dev 환경** (`envs/dev/terraform.tfvars`):
```hcl
whitelist_ips = [
  "203.0.113.0/32",  # 개발팀 사무실
]
```

**Prod 환경** (`envs/prod/terraform.tfvars`):
```hcl
whitelist_ips = [
  "203.0.113.0/32",  # 운영팀 사무실
  "198.51.100.0/32", # VPN 서버
]
```

## 검증

### DNS 레코드 검증
```bash
# Dev 환경
dig kafka.goormpopcorn.shop
dig argocd.goormpopcorn.shop
dig grafana.goormpopcorn.shop

# Prod 환경
dig kafka.goormpopcorn.shop
dig argocd.goormpopcorn.shop
dig grafana.goormpopcorn.shop
```

### ALB 연결 검증
```bash
# Management ALB DNS 확인
terraform output -state=envs/dev/terraform.tfstate management_alb_dns_name
terraform output -state=envs/prod/terraform.tfstate management_alb_dns_name

# 헬스체크 확인
curl -I https://kafka.goormpopcorn.shop
curl -I https://argocd.goormpopcorn.shop
curl -I https://grafana.goormpopcorn.shop
```

## Task 5.3: Route53 헬스체크 설정

**상태**: ⏭️ 다음 작업

**설명**: 모든 서브도메인에 헬스체크를 구성하여 ALB 상태를 모니터링합니다.

## 다음 단계

1. ⏭️ Task 5.3: Route53 헬스체크 설정
2. ⏭️ Task 6.1: EKS 모듈에 Helm provider 추가
3. ⏭️ Task 6.2: Helm 설치 리소스 추가

## 참고사항

### Route53 Alias 레코드 장점
- **비용 절감**: Alias 레코드는 무료
- **자동 업데이트**: ALB DNS가 변경되어도 자동으로 업데이트
- **헬스체크**: ALB 헬스체크를 자동으로 평가

### Management ALB 보안
- IP 화이트리스트를 통해 관리 도구 접근 제한
- HTTPS 강제 (ACM 인증서 사용)
- 보안 그룹 규칙으로 네트워크 레벨 제어

### 도메인 구조
```
goormpopcorn.shop (Public ALB - Frontend)
├── api.goormpopcorn.shop (Public ALB - API Gateway)
└── Management ALB (IP 화이트리스트)
    ├── kafka.goormpopcorn.shop (Kafka UI)
    ├── argocd.goormpopcorn.shop (ArgoCD)
    └── grafana.goormpopcorn.shop (Grafana)
```

## 결론

Task 5.1과 5.2는 이미 완료된 상태로 확인되었습니다. Dev 및 Prod 환경 모두 Management ALB에 대한 Route53 레코드가 올바르게 설정되어 있으며, 보안 그룹을 통해 IP 화이트리스트 기반 접근 제어가 구현되어 있습니다.
