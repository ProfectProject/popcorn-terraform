# Route53-ACM 모듈 통합 가이드

## 📋 통합 배경

### 문제점
- `modules/route53-acm/`: 재사용 가능한 모듈
- `global/route53-acm/`: 위 모듈을 단순히 호출하는 래퍼
- **하나의 도메인**(`goormpopcorn.shop`)만 관리
- **불필요한 중복 구조**로 복잡성 증가

### 해결책
- `global/route53-acm/`에 직접 구현
- `modules/route53-acm/` 제거
- 단순하고 명확한 구조로 변경

## 🔄 변경사항

### Before (통합 전)
```
modules/route53-acm/          # 재사용 가능한 모듈
├── main.tf                   # Route53 + ACM 리소스
├── variables.tf              # 변수 정의
└── outputs.tf                # 출력 정의

global/route53-acm/           # 모듈 호출 래퍼
├── main.tf                   # modules/route53-acm 호출
├── outputs.tf                # 모듈 출력 전달
├── backend.tf                # S3 백엔드 설정
└── versions.tf               # Provider 버전
```

### After (통합 후)
```
global/route53-acm/           # 직접 구현
├── main.tf                   # Route53 + ACM 리소스 직접 정의
├── outputs.tf                # 출력 정의
├── backend.tf                # S3 백엔드 설정
└── versions.tf               # Provider 버전
```

## 📝 변경된 파일 내용

### `global/route53-acm/main.tf`
```hcl
provider "aws" {
  region = "ap-northeast-2"
}

locals {
  zone_name = "goormpopcorn.shop"
  base_tags = {
    Name        = local.zone_name
    Environment = "global"
    Project     = "goorm-popcorn"
    ManagedBy   = "terraform"
  }
}

resource "aws_route53_zone" "this" {
  name = local.zone_name
  tags = local.base_tags
}

resource "aws_acm_certificate" "this" {
  domain_name               = local.zone_name
  validation_method         = "DNS"
  subject_alternative_names = [
    "*.goormpopcorn.shop",
  ]
  tags = local.base_tags
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
```

### `global/route53-acm/outputs.tf`
```hcl
output "zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Route53 hosted zone name servers"
  value       = aws_route53_zone.this.name_servers
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate_validation.this.certificate_arn
}
```

## 🚀 통합 효과

### ✅ **장점**
1. **구조 단순화**: 불필요한 모듈 계층 제거
2. **유지보수 용이**: 하나의 위치에서 관리
3. **명확성 향상**: 직접적인 리소스 정의
4. **파일 수 감소**: 3개 파일 제거

### ⚠️ **고려사항**
1. **재사용성 감소**: 다른 도메인 추가 시 코드 복제 필요
2. **모듈화 철학**: 일반적인 Terraform 모듈 패턴과 다름

### 💡 **언제 다시 모듈화할까?**
- 여러 도메인 관리가 필요한 경우
- 다른 프로젝트에서 재사용이 필요한 경우
- 복잡한 Route53 설정이 필요한 경우

## 🔧 마이그레이션 절차

### 1. 기존 상태 확인
```bash
cd global/route53-acm
terraform state list
```

### 2. 통합 후 계획 확인
```bash
terraform plan
# 변경사항이 없어야 함 (리소스는 동일)
```

### 3. 적용 (필요시)
```bash
terraform apply
```

## 📊 영향 분석

### **변경되지 않는 것**
- ✅ Route53 Hosted Zone
- ✅ ACM Certificate
- ✅ DNS 검증 레코드
- ✅ 환경별 참조 (dev/prod)
- ✅ S3 백엔드 상태

### **변경되는 것**
- 🔄 파일 구조 단순화
- 🔄 코드 위치 변경
- 🔄 README 문서 업데이트

## 🎯 결론

이번 통합으로 **단일 도메인 관리**라는 현재 요구사항에 맞는 **최적화된 구조**를 구축했습니다.

### **핵심 가치**
- **KISS 원칙**: Keep It Simple, Stupid
- **YAGNI 원칙**: You Aren't Gonna Need It
- **실용성 우선**: 현재 요구사항에 최적화

향후 여러 도메인 관리가 필요해지면 언제든 모듈로 다시 분리할 수 있습니다.

---

**통합 완료일**: 2026-01-27  
**영향 범위**: 구조 최적화 (기능 변경 없음)  
**다음 단계**: 정상 동작 확인 후 배포