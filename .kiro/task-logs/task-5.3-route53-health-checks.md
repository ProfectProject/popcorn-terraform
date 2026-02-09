# Task 5.3: Route53 헬스체크 설정

## 작업 일시
2026-02-09

## 작업 내용

Dev 및 Prod 환경의 모든 Management ALB 서브도메인에 Route53 헬스체크를 추가하여 ALB 상태를 모니터링합니다.

## 추가된 헬스체크

### Dev 환경
**파일**: `popcorn-terraform-feature/envs/dev/main.tf`

```hcl
# Route53 헬스체크 - Management ALB 서브도메인
resource "aws_route53_health_check" "kafka" {
  fqdn              = "kafka.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "kafka-goormpopcorn-shop-health-check"
  })
}

resource "aws_route53_health_check" "argocd" {
  fqdn              = "argocd.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "argocd-goormpopcorn-shop-health-check"
  })
}

resource "aws_route53_health_check" "grafana" {
  fqdn              = "grafana.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "grafana-goormpopcorn-shop-health-check"
  })
}
```

### Prod 환경
**파일**: `popcorn-terraform-feature/envs/prod/main.tf`

동일한 헬스체크 리소스를 Prod 환경에도 추가했습니다.

## 헬스체크 설정 상세

### 기본 설정
- **프로토콜**: HTTPS (포트 443)
- **리소스 경로**: `/` (루트 경로)
- **실패 임계값**: 3회 연속 실패 시 Unhealthy 상태로 전환
- **요청 간격**: 30초마다 헬스체크 수행

### 헬스체크 대상
1. **kafka.goormpopcorn.shop**
   - Kafka UI 서비스 상태 모니터링
   - Management ALB를 통한 접근

2. **argocd.goormpopcorn.shop**
   - ArgoCD 서비스 상태 모니터링
   - Management ALB를 통한 접근

3. **grafana.goormpopcorn.shop**
   - Grafana 서비스 상태 모니터링
   - Management ALB를 통한 접근

## 헬스체크 동작 방식

### 정상 상태 (Healthy)
- HTTPS 요청이 성공적으로 응답 (2xx, 3xx 상태 코드)
- 30초마다 헬스체크 수행
- 연속 3회 성공 시 Healthy 상태 유지

### 비정상 상태 (Unhealthy)
- HTTPS 요청 실패 또는 타임아웃
- 연속 3회 실패 시 Unhealthy 상태로 전환
- CloudWatch 알람 트리거 가능

### 헬스체크 흐름
```
Route53 Health Checker
    ↓ (30초마다)
HTTPS 요청 → kafka.goormpopcorn.shop
    ↓
Management ALB
    ↓
EKS Kafka UI Pod
    ↓
응답 (2xx/3xx) → Healthy
응답 실패 (3회) → Unhealthy
```

## 모니터링 및 알람

### CloudWatch 메트릭
Route53 헬스체크는 자동으로 CloudWatch 메트릭을 생성합니다:
- `HealthCheckStatus`: 헬스체크 상태 (0 = Unhealthy, 1 = Healthy)
- `HealthCheckPercentageHealthy`: 헬스체크 성공률

### CloudWatch 알람 설정 (선택적)
```hcl
# 예시: Kafka 헬스체크 알람
resource "aws_cloudwatch_metric_alarm" "kafka_health_check" {
  alarm_name          = "kafka-goormpopcorn-shop-unhealthy"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Kafka UI is unhealthy"
  
  dimensions = {
    HealthCheckId = aws_route53_health_check.kafka.id
  }
}
```

## 검증

### Terraform 검증
```bash
# Dev 환경
cd popcorn-terraform-feature/envs/dev
terraform init
terraform validate
terraform plan

# Prod 환경
cd popcorn-terraform-feature/envs/prod
terraform init
terraform validate
terraform plan
```

### 헬스체크 상태 확인
```bash
# AWS CLI로 헬스체크 상태 확인
aws route53 get-health-check-status --health-check-id <health-check-id>

# 모든 헬스체크 목록 조회
aws route53 list-health-checks
```

### 헬스체크 테스트
```bash
# 수동으로 HTTPS 요청 테스트
curl -I https://kafka.goormpopcorn.shop
curl -I https://argocd.goormpopcorn.shop
curl -I https://grafana.goormpopcorn.shop
```

## 비용 고려사항

### Route53 헬스체크 비용
- **기본 헬스체크**: $0.50/월 per health check
- **총 비용**: $1.50/월 (3개 헬스체크)
- **요청 간격**: 30초 (표준 간격, 추가 비용 없음)

### 비용 최적화 옵션
1. **Fast Interval 비활성화**: 10초 간격은 추가 비용 발생 ($1.00/월 추가)
2. **Latency Measurement 비활성화**: 지연 시간 측정은 추가 비용 발생
3. **String Matching 비활성화**: 응답 본문 검증은 추가 비용 발생

## 보안 고려사항

### HTTPS 헬스체크
- TLS/SSL 인증서 검증 수행
- ACM 인증서를 통한 암호화된 통신
- Management ALB의 보안 그룹 규칙 준수

### IP 화이트리스트
- Route53 헬스체커 IP는 AWS 관리 IP 범위
- Management ALB 보안 그룹에서 Route53 헬스체커 IP 허용 필요
- 현재 설정: 화이트리스트 IP만 허용 (헬스체크는 AWS 내부에서 수행)

## 트러블슈팅

### 문제 1: 헬스체크가 항상 Unhealthy
**원인**: 
- Management ALB 보안 그룹이 Route53 헬스체커 IP를 차단
- 백엔드 서비스가 응답하지 않음
- HTTPS 인증서 문제

**해결**:
1. Management ALB 보안 그룹 규칙 확인
2. EKS Pod 상태 확인 (`kubectl get pods`)
3. ALB 타겟 그룹 헬스체크 확인
4. ACM 인증서 상태 확인

### 문제 2: 헬스체크가 간헐적으로 실패
**원인**:
- 백엔드 서비스의 간헐적 지연
- ALB 타겟 그룹의 Unhealthy 타겟

**해결**:
1. `failure_threshold` 증가 (3 → 5)
2. `request_interval` 증가 (30초 → 60초)
3. 백엔드 서비스 성능 최적화

### 문제 3: 헬스체크 비용이 예상보다 높음
**원인**:
- Fast Interval 활성화
- String Matching 활성화

**해결**:
1. 헬스체크 설정 검토
2. 불필요한 옵션 비활성화
3. 헬스체크 수 최소화

## 다음 단계

### Task 6.1: EKS 모듈에 Helm provider 추가
- Helm provider 설정
- Kubernetes provider 설정

### Task 6.2: Helm 설치 리소스 추가
- helm_release 리소스 정의
- enable_helm 변수 추가

## 참고사항

### Route53 헬스체크 장점
- **자동 장애 감지**: 서비스 장애 시 자동으로 감지
- **CloudWatch 통합**: 메트릭 및 알람 자동 생성
- **글로벌 모니터링**: 여러 AWS 리전에서 헬스체크 수행

### 헬스체크 vs ALB 헬스체크
- **Route53 헬스체크**: DNS 레벨에서 엔드포인트 상태 모니터링
- **ALB 헬스체크**: 타겟 그룹 레벨에서 백엔드 인스턴스 상태 모니터링
- **둘 다 필요**: Route53은 ALB 자체 상태, ALB는 백엔드 상태 모니터링

### 모범 사례
1. **적절한 임계값 설정**: 너무 낮으면 False Positive, 너무 높으면 장애 감지 지연
2. **CloudWatch 알람 연동**: 헬스체크 실패 시 SNS 알림 전송
3. **정기적인 검토**: 헬스체크 설정이 서비스 특성에 맞는지 확인

## 결론

Task 5.3이 완료되었습니다. Dev 및 Prod 환경의 모든 Management ALB 서브도메인에 Route53 헬스체크가 추가되어 서비스 상태를 지속적으로 모니터링할 수 있습니다.

헬스체크는 30초마다 HTTPS 요청을 수행하며, 연속 3회 실패 시 Unhealthy 상태로 전환됩니다. CloudWatch 메트릭과 연동하여 알람을 설정할 수 있습니다.
