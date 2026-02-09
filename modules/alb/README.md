# ALB (Application Load Balancer) 모듈

## 개요

이 모듈은 AWS Application Load Balancer(ALB)를 생성하고 관리합니다. Public ALB와 Management ALB를 구성하여 외부 사용자 트래픽과 관리 도구 트래픽을 분리합니다.

## 주요 기능

- **ALB 생성**: Public Subnet에 Application Load Balancer 배치
- **HTTPS 리스너**: ACM 인증서를 사용한 HTTPS 리스너 구성
- **HTTP to HTTPS 리다이렉트**: 모든 HTTP 트래픽을 HTTPS로 자동 리다이렉트
- **타겟 그룹**: EKS Ingress Controller가 관리하는 기본 타겟 그룹
- **CloudWatch 모니터링**: ALB 메트릭 및 알람 구성
- **액세스 로그**: S3 버킷에 ALB 액세스 로그 저장 (선택적)

## 사용 예제

### Public ALB (외부 사용자 접근용)

```hcl
module "public_alb" {
  source = "../../modules/alb"

  name               = "popcorn-prod-public-alb"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.public_alb_sg_id]
  internal           = false
  certificate_arn    = data.aws_acm_certificate.main.arn

  target_group_name  = "popcorn-prod-public-tg"
  target_group_port  = 80
  health_check_path  = "/"

  # CloudWatch 모니터링
  enable_cloudwatch_alarms = true
  sns_topic_arn            = aws_sns_topic.alarms.arn

  # 액세스 로그 (선택적)
  enable_access_logs   = true
  access_logs_bucket   = "popcorn-prod-alb-logs"
  access_logs_prefix   = "public-alb"

  tags = {
    Environment = "prod"
    Project     = "popcorn"
    Type        = "public"
  }
}
```

### Management ALB (관리 도구 접근용)

```hcl
module "management_alb" {
  source = "../../modules/alb"

  name               = "popcorn-prod-mgmt-alb"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.management_alb_sg_id]
  internal           = false
  certificate_arn    = data.aws_acm_certificate.main.arn

  target_group_name  = "popcorn-prod-mgmt-tg"
  target_group_port  = 80
  health_check_path  = "/"

  # CloudWatch 모니터링
  enable_cloudwatch_alarms = true
  sns_topic_arn            = aws_sns_topic.alarms.arn

  tags = {
    Environment = "prod"
    Project     = "popcorn"
    Type        = "management"
  }
}
```

### Host-based 라우팅 사용 예제

```hcl
module "alb_with_routing" {
  source = "../../modules/alb"

  name               = "popcorn-prod-alb"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  security_group_ids = [module.security_groups.alb_sg_id]
  internal           = false
  certificate_arn    = data.aws_acm_certificate.main.arn

  # 기본 타겟 그룹
  target_group_name  = "popcorn-default-tg"
  target_group_port  = 80
  health_check_path  = "/"

  # 추가 타겟 그룹 (Host-based 라우팅용)
  target_groups = [
    {
      name     = "kafka-ui-tg"
      port     = 8080
      protocol = "HTTP"
      health_check = {
        path                = "/health"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
        matcher             = "200"
      }
    },
    {
      name     = "argocd-tg"
      port     = 8080
      protocol = "HTTP"
      health_check = {
        path                = "/healthz"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
        matcher             = "200"
      }
    }
  ]

  # 리스너 규칙 (Host-based 라우팅)
  listener_rules = [
    {
      priority           = 100
      host_header        = "kafka.goormpopcorn.shop"
      target_group_index = 0  # kafka-ui-tg
    },
    {
      priority           = 200
      host_header        = "argocd.goormpopcorn.shop"
      target_group_index = 1  # argocd-tg
    }
  ]

  tags = {
    Environment = "prod"
    Project     = "popcorn"
  }
}
```

## 입력 변수

### 필수 변수

| 변수명 | 타입 | 설명 |
|--------|------|------|
| `name` | `string` | ALB 이름 |
| `vpc_id` | `string` | VPC ID |
| `subnet_ids` | `list(string)` | ALB를 배치할 서브넷 ID 목록 (Public Subnet) |
| `security_group_ids` | `list(string)` | ALB에 연결할 Security Group ID 목록 |
| `certificate_arn` | `string` | HTTPS 리스너에 사용할 ACM 인증서 ARN |

### 선택적 변수

| 변수명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `internal` | `bool` | `false` | 내부 ALB 여부 (true: 내부, false: 외부) |
| `target_group_name` | `string` | `null` | 기본 타겟 그룹 이름 (null인 경우 자동 생성) |
| `target_group_port` | `number` | `8080` | 기본 타겟 그룹 포트 |
| `health_check_path` | `string` | `"/actuator/health"` | 기본 헬스체크 경로 |
| `target_groups` | `list(object)` | `[]` | 추가 타겟 그룹 목록 (Host-based 라우팅용) |
| `listener_rules` | `list(object)` | `[]` | 리스너 규칙 목록 (Host-based 라우팅) |
| `enable_access_logs` | `bool` | `false` | ALB 액세스 로그 활성화 여부 |
| `access_logs_bucket` | `string` | `null` | 액세스 로그를 저장할 S3 버킷 이름 |
| `access_logs_prefix` | `string` | `"alb"` | S3 버킷 내 로그 저장 경로 prefix |
| `enable_cloudwatch_alarms` | `bool` | `true` | CloudWatch 알람 활성화 여부 |
| `sns_topic_arn` | `string` | `null` | CloudWatch 알람 알림을 받을 SNS Topic ARN |
| `tags` | `map(string)` | `{}` | 리소스에 적용할 태그 |

## 출력 값

| 출력명 | 타입 | 설명 |
|--------|------|------|
| `alb_arn` | `string` | ALB ARN |
| `alb_arn_suffix` | `string` | ALB ARN suffix (CloudWatch 메트릭용) |
| `alb_dns_name` | `string` | ALB DNS 이름 |
| `alb_zone_id` | `string` | ALB Zone ID (Route53 레코드 생성용) |
| `default_target_group_arn` | `string` | 기본 타겟 그룹 ARN |
| `target_group_arns` | `list(string)` | 모든 타겟 그룹 ARN 목록 (기본 + 추가) |
| `listener_arn` | `string` | HTTPS 리스너 ARN |
| `http_listener_arn` | `string` | HTTP 리스너 ARN (리다이렉트용) |

## 리소스

이 모듈은 다음 AWS 리소스를 생성합니다:

- `aws_lb`: Application Load Balancer
- `aws_lb_target_group`: 기본 타겟 그룹
- `aws_lb_target_group`: 추가 타겟 그룹 (Host-based 라우팅용, 선택적)
- `aws_lb_listener`: HTTP 리스너 (HTTPS로 리다이렉트)
- `aws_lb_listener`: HTTPS 리스너 (ACM 인증서 사용)
- `aws_lb_listener_rule`: Host-based 라우팅 규칙 (선택적)
- `aws_s3_bucket`: ALB 액세스 로그 버킷 (선택적)
- `aws_cloudwatch_metric_alarm`: ALB 메트릭 알람 (선택적)

## CloudWatch 알람

이 모듈은 다음 CloudWatch 알람을 생성합니다 (`enable_cloudwatch_alarms = true`인 경우):

1. **높은 응답 시간**: 평균 응답 시간이 1초를 초과하는 경우
2. **높은 4xx 에러율**: 5분 동안 4xx 에러가 10개를 초과하는 경우
3. **높은 5xx 에러율**: 5분 동안 5xx 에러가 5개를 초과하는 경우

## 보안 고려사항

### Public ALB
- Security Group에서 인터넷(0.0.0.0/0)에서 80, 443 포트 접근 허용
- HTTP 트래픽은 자동으로 HTTPS로 리다이렉트
- TLS 1.3 정책 사용 (`ELBSecurityPolicy-TLS13-1-2-2021-06`)

### Management ALB
- Security Group에서 화이트리스트 IP에서만 80, 443 포트 접근 허용
- 관리 도구(Kafka UI, ArgoCD, Grafana) 접근 제한
- TLS 1.3 정책 사용

## Route53 연동

ALB를 Route53 도메인에 연결하려면 다음과 같이 설정합니다:

```hcl
# Public ALB - goormpopcorn.shop
resource "aws_route53_record" "public_alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.public_alb.alb_dns_name
    zone_id                = module.public_alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Management ALB - kafka.goormpopcorn.shop
resource "aws_route53_record" "kafka" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "kafka.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}
```

## EKS Ingress Controller 연동

이 ALB는 AWS Load Balancer Controller와 함께 사용됩니다. Kubernetes Ingress 리소스를 생성하면 자동으로 ALB에 리스너 규칙이 추가됩니다.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    alb.ingress.kubernetes.io/load-balancer-name: popcorn-prod-public-alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
spec:
  ingressClassName: alb
  rules:
  - host: goormpopcorn.shop
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

## 비용 최적화

- **Dev 환경**: 단일 AZ에 ALB 배치하여 비용 절감
- **Prod 환경**: Multi-AZ에 ALB 배치하여 고가용성 보장
- **액세스 로그**: 필요한 경우에만 활성화 (S3 스토리지 비용 발생)
- **S3 라이프사이클**: 30일 후 자동 삭제로 스토리지 비용 절감

## 트러블슈팅

### ALB가 생성되지 않는 경우
- VPC와 Subnet이 올바르게 설정되었는지 확인
- Security Group이 올바르게 생성되었는지 확인
- ACM 인증서가 발급되었는지 확인

### HTTPS 리스너가 작동하지 않는 경우
- ACM 인증서 ARN이 올바른지 확인
- 인증서가 `ISSUED` 상태인지 확인
- 도메인이 올바르게 설정되었는지 확인

### 타겟 그룹에 트래픽이 전달되지 않는 경우
- Security Group 규칙이 올바른지 확인
- EKS Node Security Group에서 ALB 접근을 허용하는지 확인
- 헬스체크 경로가 올바른지 확인

## 참고 자료

- [AWS Application Load Balancer 문서](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [AWS Load Balancer Controller 문서](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Terraform aws_lb 리소스](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb)

## 라이선스

이 모듈은 Goorm Popcorn 프로젝트의 일부입니다.

## 작성자

DevOps Team

## 버전

- **v1.1.0**: 변수명 개선 및 기능 추가 (2025-02-05)
  - `public_subnet_ids` → `subnet_ids`로 변수명 변경
  - `security_group_id` → `security_group_ids`로 변경 (복수형 지원)
  - `internal` 변수 추가 (내부/외부 ALB 선택 가능)
  - `target_group_arns` 출력 추가
  - `http_listener_arn` 출력 추가
  - Host-based 라우팅 기능 추가
  - 한국어 주석 및 문서 개선
- **v1.0.0**: 초기 버전 (2025-02-05)
  - ALB 생성 및 HTTPS 리스너 구성
  - CloudWatch 모니터링 및 알람
  - 액세스 로그 S3 저장
