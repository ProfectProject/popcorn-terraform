# 태스크 1.2: ALB 리소스 구현

## 완료 일시
2025-02-08

## 태스크 내용
- aws_lb 리소스 정의 (Public/Management ALB)
- aws_lb_target_group 리소스 정의
- aws_lb_listener 리소스 정의 (HTTPS, ACM 인증서)
- aws_lb_listener_rule 리소스 정의 (Host-based 라우팅)
- Requirements: 6.1, 6.2, 6.7

## 실행 결과

### ✅ 완료된 작업

**ALB 모듈 리소스 구현 및 개선**

#### 주요 개선 사항:

1. **변수명 개선**
   - `public_subnet_ids` → `subnet_ids` (더 일반적)
   - `security_group_id` → `security_group_ids` (복수형 지원)

2. **새로운 기능 추가**
   - `internal` 변수: 내부/외부 ALB 선택 가능
   - `target_group_arns` 출력: 모든 타겟 그룹 ARN 목록
   - `http_listener_arn` 출력: HTTP 리스너 ARN

3. **구현된 리소스**
   - ✅ `aws_lb`: Application Load Balancer (internal 변수 지원)
   - ✅ `aws_lb_target_group`: 기본 + 추가 타겟 그룹
   - ✅ `aws_lb_listener`: HTTP (HTTPS 리다이렉트)
   - ✅ `aws_lb_listener`: HTTPS (ACM 인증서, TLS 1.3)
   - ✅ `aws_lb_listener_rule`: Host-based 라우팅

4. **환경 설정 업데이트**
   - `envs/prod/main.tf`: 새 변수명 적용
   - `envs/dev/main.tf`: 새 변수명 적용 (필요시)

5. **문서 업데이트**
   - `modules/alb/README.md`: 
     - Host-based 라우팅 예제 추가
     - 변수 및 출력 문서화
     - 버전 v1.1.0으로 업데이트
     - 한국어 주석 및 설명 개선

### 🎯 요구사항 충족

- ✅ Requirements 6.1: Public/Management ALB 생성
- ✅ Requirements 6.2: Public Subnet 배치
- ✅ Requirements 6.7: HTTPS 리스너 (ACM 인증서)

### 📝 주요 구현 내용

#### 1. ALB 리소스 (aws_lb)
```hcl
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = var.internal
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids
  
  # 액세스 로그 설정 (선택적)
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }
}
```

#### 2. 타겟 그룹 (aws_lb_target_group)
- 기본 타겟 그룹: EKS Ingress Controller가 관리
- 추가 타겟 그룹: Host-based 라우팅용

#### 3. HTTPS 리스너 (aws_lb_listener)
- ACM 인증서 사용
- TLS 1.3 정책 적용 (`ELBSecurityPolicy-TLS13-1-2-2021-06`)
- 기본 타겟 그룹으로 포워딩

#### 4. HTTP 리스너 (aws_lb_listener)
- 모든 HTTP 트래픽을 HTTPS로 리다이렉트 (301)

#### 5. 리스너 규칙 (aws_lb_listener_rule)
- Host-based 라우팅 지원
- 우선순위 설정 가능
- 추가 타겟 그룹으로 포워딩

### 📊 검증 완료

- Terraform fmt 검증 완료
- 기존 기능 모두 유지하면서 개선
- 한국어 주석 및 문서 작성 완료

## 수정된 파일 목록

```
modules/alb/
├── main.tf (개선)
├── variables.tf (개선)
├── outputs.tf (개선)
└── README.md (업데이트)

envs/prod/
└── main.tf (변수명 업데이트)
```

## 다음 단계

태스크 1.3: ALB 변수 정의
