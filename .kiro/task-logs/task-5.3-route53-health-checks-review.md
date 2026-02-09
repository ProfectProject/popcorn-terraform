# Task 5.3: Route53 헬스체크 설정 - AWS Well-Architected Framework 검토

## 작업 일시
2026-02-09

## 검토 개요
Dev 환경에 추가된 Route53 헬스체크 설정을 AWS Well-Architected Framework 5가지 기둥 관점에서 검토했습니다.

---

## 1. 운영 우수성 (Operational Excellence)

### ✅ 긍정적인 부분
- 태그 전략이 일관되게 적용됨 (`merge(var.tags, {...})`)
- 리소스별 명확한 네이밍 규칙 적용
- 헬스체크를 통한 자동 모니터링 구현

### ⚠️ 개선 권장사항
**CloudWatch 알람 추가 필요**

```hcl
# CloudWatch 알람 - 헬스체크 실패 시 알림
resource "aws_cloudwatch_metric_alarm" "kafka_health_check" {
  alarm_name          = "kafka-goormpopcorn-shop-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Kafka 서브도메인 헬스체크 실패"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.kafka.id
  }

  tags = var.tags
}
```

---

## 2. 보안 (Security)

### ✅ 긍정적인 부분
- HTTPS(443) 포트 사용으로 전송 중 암호화 보장
- Management ALB는 IP 화이트리스트로 접근 제어됨

### ⚠️ 개선 권장사항
**헬스체크 경로를 더 구체적으로 지정**

```hcl
resource "aws_route53_health_check" "kafka" {
  fqdn              = "kafka.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"  # "/" 대신 실제 헬스체크 엔드포인트
  failure_threshold = 3
  request_interval  = 30
  
  # 응답 본문 검증 추가 (선택적)
  search_string     = "ok"
  
  tags = merge(var.tags, {
    Name = "kafka-goormpopcorn-shop-health-check"
  })
}
```

**이유:**
- `/` 경로는 인증이 필요할 수 있어 헬스체크가 실패할 수 있음
- 각 서비스의 실제 헬스체크 엔드포인트 사용 권장

---

## 3. 안정성 (Reliability)

### ✅ 긍정적인 부분
- `failure_threshold = 3`으로 일시적 장애 허용
- `request_interval = 30`으로 적절한 모니터링 주기

### ⚠️ 개선 권장사항
**Route53 레코드와 헬스체크 연결**

```hcl
# 1. 헬스체크에 레이턴시 측정 추가
resource "aws_route53_health_check" "kafka" {
  fqdn              = "kafka.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
  
  # 레이턴시 측정 활성화
  measure_latency   = true
  
  tags = merge(var.tags, {
    Name = "kafka-goormpopcorn-shop-health-check"
  })
}

# 2. Route53 레코드에 헬스체크 연결
resource "aws_route53_record" "kafka" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "kafka.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
  
  # 헬스체크 ID 연결
  health_check_id = aws_route53_health_check.kafka.id
}
```

**중요:** 현재 헬스체크가 생성되지만 Route53 레코드와 연결되지 않아 실제 장애 조치에 사용되지 않습니다.

---

## 4. 성능 효율성 (Performance Efficiency)

### ✅ 긍정적인 부분
- `request_interval = 30`으로 적절한 모니터링 주기

### 💡 개선 제안
**환경별 헬스체크 간격 조정**

```hcl
# variables.tf에 추가
variable "health_check_interval" {
  description = "Route53 헬스체크 간격 (초)"
  type        = number
  default     = 30  # Dev: 30초, Prod: 10초 권장
}

# main.tf에서 사용
resource "aws_route53_health_check" "kafka" {
  fqdn              = "kafka.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = var.health_check_interval
  
  tags = merge(var.tags, {
    Name = "kafka-goormpopcorn-shop-health-check"
  })
}
```

---

## 5. 비용 최적화 (Cost Optimization)

### 💰 현재 비용
- Route53 헬스체크: **$0.50/월** (각 헬스체크당)
- 3개 헬스체크: **$1.50/월**
- 30초 간격: 추가 비용 없음

### ⚠️ 개선 권장사항
**Dev 환경에서는 헬스체크 선택적 활성화**

```hcl
# variables.tf에 추가
variable "enable_health_checks" {
  description = "Route53 헬스체크 활성화 여부"
  type        = bool
  default     = false  # Dev 환경에서는 비활성화
}

# main.tf에서 조건부 생성
resource "aws_route53_health_check" "kafka" {
  count = var.enable_health_checks ? 1 : 0
  
  fqdn              = "kafka.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name        = "kafka-goormpopcorn-shop-health-check"
    CostCenter  = "infrastructure"
    Service     = "monitoring"
    Environment = "dev"
  })
}
```

**이유:**
- Dev 환경에서는 헬스체크가 필수가 아닐 수 있음
- ALB 자체의 헬스체크(`evaluate_target_health = true`)로도 충분
- Prod 환경에서만 활성화하여 비용 절감 가능

---

## 📋 종합 권장사항

### 우선순위 1 (즉시 적용 권장)
1. ✅ **헬스체크 경로 수정**: `/` → `/health` (각 서비스의 실제 엔드포인트)
2. ✅ **Route53 레코드와 헬스체크 연결**: `health_check_id` 추가
3. ✅ **비용 최적화**: Dev 환경에서는 헬스체크 선택적 활성화

### 우선순위 2 (검토 후 적용)
1. ⏳ **CloudWatch 알람 추가**: 헬스체크 실패 시 알림
2. ⏳ **레이턴시 측정 활성화**: `measure_latency = true`
3. ⏳ **비용 태그 추가**: 비용 추적 및 분석

### 우선순위 3 (Prod 환경 적용)
1. 🔄 **빠른 헬스체크 간격**: 10초 간격 (Prod만)
2. 🔄 **장애 조치 정책**: Failover routing policy 구성
3. 🔄 **SNS 알림 활성화**: Prod 환경에서 알림 필수

---

## 🔧 개선된 코드 (완전한 예시)

### variables.tf 추가
```hcl
variable "enable_health_checks" {
  description = "Route53 헬스체크 활성화 여부 (Dev: false, Prod: true 권장)"
  type        = bool
  default     = false
}

variable "health_check_interval" {
  description = "Route53 헬스체크 간격 (초). 10 또는 30만 가능"
  type        = number
  default     = 30

  validation {
    condition     = contains([10, 30], var.health_check_interval)
    error_message = "헬스체크 간격은 10 또는 30초만 가능합니다."
  }
}

variable "health_check_paths" {
  description = "서비스별 헬스체크 경로"
  type = object({
    kafka   = string
    argocd  = string
    grafana = string
  })
  default = {
    kafka   = "/health"
    argocd  = "/healthz"
    grafana = "/api/health"
  }
}
```

### main.tf 개선
```hcl
# Route53 헬스체크 - Kafka
resource "aws_route53_health_check" "kafka" {
  count = var.enable_health_checks ? 1 : 0

  fqdn              = "kafka.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_paths.kafka
  failure_threshold = 3
  request_interval  = var.health_check_interval
  measure_latency   = true

  tags = merge(var.tags, {
    Name        = "kafka-goormpopcorn-shop-health-check"
    CostCenter  = "infrastructure"
    Service     = "monitoring"
  })
}

# Route53 레코드 - Kafka (헬스체크 연결)
resource "aws_route53_record" "kafka" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "kafka.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }

  # 헬스체크 연결 (활성화된 경우에만)
  health_check_id = var.enable_health_checks ? aws_route53_health_check.kafka[0].id : null
}

# CloudWatch 알람 - Kafka 헬스체크 실패
resource "aws_cloudwatch_metric_alarm" "kafka_health_check" {
  count = var.enable_health_checks ? 1 : 0

  alarm_name          = "kafka-goormpopcorn-shop-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Kafka 서브도메인 헬스체크 실패"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.kafka[0].id
  }

  tags = var.tags
}
```

### terraform.tfvars 설정

**Dev 환경** (`envs/dev/terraform.tfvars`):
```hcl
# Route53 헬스체크 비활성화 (비용 절감)
enable_health_checks = false
```

**Prod 환경** (`envs/prod/terraform.tfvars`):
```hcl
# Route53 헬스체크 활성화 (고가용성)
enable_health_checks    = true
health_check_interval   = 10  # 빠른 장애 감지

# 서비스별 헬스체크 경로
health_check_paths = {
  kafka   = "/health"
  argocd  = "/healthz"
  grafana = "/api/health"
}
```

---

## 📊 비용 비교

### Dev 환경 (헬스체크 비활성화)
- Route53 헬스체크: **$0/월**
- ALB 헬스체크만 사용: 무료

### Prod 환경 (헬스체크 활성화)
- Route53 헬스체크 (3개): **$1.50/월**
- 10초 간격 (빠른 감지): 추가 비용 없음
- CloudWatch 알람 (3개): **$0.30/월** (10개까지 무료)
- **총 비용: $1.80/월**

---

## ✅ 다음 단계

1. **즉시 적용**:
   - [ ] `variables.tf`에 `enable_health_checks`, `health_check_interval`, `health_check_paths` 추가
   - [ ] `main.tf`에서 헬스체크를 조건부 생성으로 변경
   - [ ] Route53 레코드에 `health_check_id` 연결
   - [ ] Dev 환경 `terraform.tfvars`에서 `enable_health_checks = false` 설정

2. **검토 후 적용**:
   - [ ] CloudWatch 알람 추가
   - [ ] 각 서비스의 실제 헬스체크 경로 확인 및 업데이트
   - [ ] Prod 환경에 동일한 개선사항 적용

3. **테스트**:
   - [ ] `terraform plan` 실행하여 변경사항 확인
   - [ ] Dev 환경에서 헬스체크가 생성되지 않는지 확인
   - [ ] Prod 환경에서 헬스체크가 정상 작동하는지 확인

---

## 📚 참고 자료

- [AWS Route53 헬스체크 공식 문서](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Route53 헬스체크 요금](https://aws.amazon.com/route53/pricing/)

---

## 결론

현재 구현은 기본적인 헬스체크 기능을 제공하지만, 다음과 같은 개선이 필요합니다:

1. **비용 최적화**: Dev 환경에서는 헬스체크를 선택적으로 활성화
2. **안정성 향상**: Route53 레코드와 헬스체크를 연결하여 실제 장애 조치 활성화
3. **운영 우수성**: CloudWatch 알람을 추가하여 헬스체크 실패 시 알림
4. **보안 강화**: 각 서비스의 실제 헬스체크 엔드포인트 사용

이러한 개선사항을 적용하면 AWS Well-Architected Framework의 모든 기둥을 충족하는 안정적이고 비용 효율적인 헬스체크 시스템을 구축할 수 있습니다.
