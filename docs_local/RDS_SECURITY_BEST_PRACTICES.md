# RDS 보안 그룹 Best Practices
## AWS Well-Architected Framework 기반

## 📋 개요

이 문서는 `modules/rds/security.tf` 파일에 대한 AWS Well-Architected Framework 검토 결과와 개선 권장사항을 제공합니다.

---

## ✅ 현재 구현의 강점

### 1. **보안 (Security)**
- ✅ Security Group ID 기반 접근 제어 (최소 권한 원칙)
- ✅ `name_prefix` 사용으로 리소스 충돌 방지
- ✅ `create_before_destroy` 라이프사이클로 무중단 업데이트
- ✅ 각 규칙에 명확한 설명 추가

### 2. **운영 우수성 (Operational Excellence)**
- ✅ 태그 전략 적용 (`merge(var.tags, {...})`)
- ✅ 유연한 구성 옵션 (`var.create_security_group`, `var.allow_vpc_cidr`)
- ✅ 명확한 주석으로 가독성 향상

---

## ⚠️ 개선이 필요한 영역

### 1. **보안 (Security) - 중요도: 🔴 높음**

#### 문제 1: 과도한 Egress 규칙

**현재 구현:**
```hcl
resource "aws_security_group_rule" "rds_egress" {
  cidr_blocks = ["0.0.0.0/0"]  # ❌ 모든 아웃바운드 허용
}
```

**문제점:**
- RDS는 일반적으로 아웃바운드 연결이 필요 없음
- 데이터 유출 위험 증가
- 최소 권한 원칙 위반

**권장사항:**
```hcl
# ✅ 필요한 경우에만 제한적으로 허용
resource "aws_security_group_rule" "rds_egress_https" {
  count = var.enable_outbound_https ? 1 : 0

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_egress_cidrs  # 특정 AWS 서비스만
  description       = "HTTPS for AWS services only"
  security_group_id = aws_security_group.rds[0].id
}
```

**사용 케이스:**
- AWS Secrets Manager 접근
- Lambda 함수 호출
- S3 데이터 내보내기

---

#### 문제 2: VPC CIDR 전체 허용

**현재 구현:**
```hcl
resource "aws_security_group_rule" "rds_ingress_vpc" {
  cidr_blocks = [var.vpc_cidr_block]  # ❌ VPC 전체 허용
}
```

**문제점:**
- VPC 내 모든 리소스가 RDS 접근 가능
- 공격 표면 증가
- 침해 시 측면 이동(Lateral Movement) 위험

**권장사항:**

**옵션 1: Bastion Host 사용 (권장)**
```hcl
# ✅ Bastion Host만 허용
resource "aws_security_group_rule" "rds_ingress_bastion" {
  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = var.bastion_security_group_id
  description              = "PostgreSQL from Bastion Host"
  security_group_id        = aws_security_group.rds[0].id
}
```

**옵션 2: 특정 서브넷만 허용**
```hcl
# ✅ 관리 서브넷만 허용
resource "aws_security_group_rule" "rds_ingress_mgmt" {
  cidr_blocks = var.management_subnet_cidrs  # 예: ["10.0.10.0/24"]
  description = "PostgreSQL from management subnet"
}
```

---

### 2. **운영 우수성 (Operational Excellence) - 중요도: 🟡 중간**

#### 누락 1: 보안 그룹 변경 모니터링

**권장사항:**
```hcl
# CloudWatch 알람 - 보안 그룹 변경 감지
resource "aws_cloudwatch_log_metric_filter" "sg_changes" {
  name           = "${var.identifier}-rds-sg-changes"
  log_group_name = var.cloudtrail_log_group_name
  pattern        = "{($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupIngress)}"

  metric_transformation {
    name      = "RDSSecurityGroupChanges"
    namespace = "CustomMetrics/RDS"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "sg_changes" {
  alarm_name          = "${var.identifier}-rds-sg-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RDSSecurityGroupChanges"
  namespace           = "CustomMetrics/RDS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert on RDS security group changes"
  alarm_actions       = var.sns_topic_arns
}
```

**이점:**
- 무단 보안 그룹 변경 즉시 감지
- 보안 사고 대응 시간 단축
- 감사 추적 강화

---

#### 누락 2: VPC Flow Logs

**권장사항:**
```hcl
# VPC Flow Logs - 보안 그룹 트래픽 모니터링
resource "aws_flow_log" "rds_sg" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = var.flow_logs_role_arn
  log_destination = var.flow_logs_destination_arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id

  tags = merge(var.tags, {
    Name    = "${var.identifier}-rds-sg-flow-logs"
    Purpose = "RDS Security Group Traffic Monitoring"
  })
}
```

**이점:**
- 비정상 트래픽 패턴 감지
- 보안 사고 조사 지원
- 네트워크 문제 해결

---

### 3. **안정성 (Reliability) - 중요도: 🟢 낮음**

#### 누락: 보안 그룹 규칙 수 제한 검증

**AWS 제한:**
- 보안 그룹당 최대 60개 규칙
- 초과 시 Terraform apply 실패

**권장사항:**
```hcl
locals {
  total_rules = length(var.allowed_security_groups) + 
                (var.allow_vpc_cidr ? 1 : 0) + 1
}

resource "null_resource" "sg_rules_warning" {
  count = local.total_rules > 50 ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "⚠️  WARNING: Security group has ${local.total_rules} rules"
      echo "   AWS limit is 60 rules per security group"
      echo "   Consider using prefix lists or consolidating rules"
    EOT
  }
}
```

---

## 📊 Well-Architected Framework 점수

| 기둥 | 현재 점수 | 개선 후 점수 | 주요 개선 사항 |
|------|-----------|--------------|----------------|
| **운영 우수성** | 7/10 | 9/10 | CloudWatch 알람, Flow Logs 추가 |
| **보안** | 6/10 | 9/10 | Egress 제한, VPC CIDR 제한 |
| **안정성** | 8/10 | 9/10 | 규칙 수 검증 추가 |
| **성능 효율성** | N/A | N/A | 보안 그룹은 성능에 영향 없음 |
| **비용 최적화** | 9/10 | 10/10 | 비용 태그 추가 |

---

## 🚀 구현 우선순위

### Phase 1: 즉시 적용 (보안 강화)
1. ✅ Egress 규칙 제거 또는 제한
2. ✅ VPC CIDR 접근을 Bastion Host로 변경
3. ✅ 비용 태그 추가

### Phase 2: 단기 (1-2주)
4. ✅ CloudWatch 알람 구성
5. ✅ VPC Flow Logs 활성화
6. ✅ 보안 그룹 규칙 수 검증

### Phase 3: 중기 (1개월)
7. ✅ VPC Endpoints 구성 (AWS 서비스 접근용)
8. ✅ AWS Config 규칙 추가 (보안 그룹 컴플라이언스)
9. ✅ 자동화된 보안 스캔 통합

---

## 📝 환경별 적용 가이드

### Dev 환경
```hcl
# envs/dev/main.tf
module "rds" {
  source = "../../modules/rds"

  # 보안 그룹 설정
  create_security_group = true
  allowed_security_groups = {
    "eks-nodes" = module.eks.node_security_group_id
  }
  
  # Dev 환경: VPC CIDR 허용 (개발 편의성)
  allow_vpc_cidr      = true
  allowed_vpc_cidrs   = [module.vpc.vpc_cidr_block]
  
  # Egress 비활성화 (불필요)
  enable_outbound_https = false
  
  # 모니터링 (선택적)
  enable_sg_change_alerts = false
  enable_flow_logs        = false
}
```

### Prod 환경
```hcl
# envs/prod/main.tf
module "rds" {
  source = "../../modules/rds"

  # 보안 그룹 설정
  create_security_group = true
  allowed_security_groups = {
    "eks-nodes" = module.eks.node_security_group_id
    "kafka"     = module.kafka.security_group_id
  }
  
  # Bastion Host만 허용 (보안 강화)
  bastion_security_group_id = module.bastion.security_group_id
  allow_vpc_cidr            = false  # ❌ VPC CIDR 비활성화
  
  # VPC Endpoints 사용 (권장)
  enable_vpc_endpoints = true
  vpc_endpoint_security_groups = {
    "secrets-manager" = module.vpc_endpoints.secrets_manager_sg_id
  }
  
  # 모니터링 활성화 (필수)
  enable_sg_change_alerts   = true
  cloudtrail_log_group_name = module.cloudtrail.log_group_name
  sns_topic_arns            = [module.sns.security_alerts_topic_arn]
  
  # VPC Flow Logs (필수)
  enable_flow_logs           = true
  flow_logs_role_arn         = module.iam.flow_logs_role_arn
  flow_logs_destination_arn  = module.cloudwatch.flow_logs_group_arn
  
  # 비용 태그
  cost_center_tag = "production-database"
}
```

---

## 🔍 검증 체크리스트

### 배포 전 검증
- [ ] Egress 규칙이 제한적인가?
- [ ] VPC CIDR 접근이 필요한가? (Prod에서는 비권장)
- [ ] Bastion Host 보안 그룹이 구성되었는가?
- [ ] CloudWatch 알람이 활성화되었는가?
- [ ] VPC Flow Logs가 활성화되었는가?
- [ ] 비용 태그가 적용되었는가?

### 배포 후 검증
- [ ] 보안 그룹 규칙이 올바르게 생성되었는가?
- [ ] CloudWatch 알람이 작동하는가?
- [ ] VPC Flow Logs가 수집되는가?
- [ ] 애플리케이션이 RDS에 연결 가능한가?
- [ ] Bastion Host에서 RDS 접근 가능한가?

---

## 📚 참고 자료

### AWS 공식 문서
- [RDS Security Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.Security.html)
- [VPC Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)

### 내부 문서
- `docs_local/MONITORING.md` - 모니터링 설정 가이드
- `docs_local/ARCHITECTURE.md` - 전체 아키텍처 문서
- `modules/rds/README.md` - RDS 모듈 사용 가이드

---

## 🤝 기여 및 피드백

개선 사항이나 질문이 있으시면 팀에 문의해주세요.

**작성일**: 2026-02-08  
**작성자**: Kiro AI  
**버전**: 1.0
