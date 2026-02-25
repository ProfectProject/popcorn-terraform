# RDS 보안 개선 권장사항
# 이 파일은 참고용입니다. 실제 적용 시 security.tf를 수정하세요.

# ============================================
# 1. VPC CIDR 접근 제한 (권장)
# ============================================

# 옵션 A: 특정 서브넷 CIDR만 허용 (권장)
variable "allowed_cidr_blocks" {
  description = "Specific CIDR blocks allowed to access RDS (e.g., private subnets only)"
  type        = list(string)
  default     = []
}

resource "aws_security_group_rule" "rds_ingress_cidr" {
  count = var.create_security_group && length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  
  type              = "ingress"
  from_port         = var.database_port
  to_port           = var.database_port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "PostgreSQL from specific subnets"
  security_group_id = aws_security_group.rds[0].id
}

# ============================================
# 2. Egress 규칙 조건부 생성
# ============================================

variable "enable_egress" {
  description = "Enable egress rules (usually not needed for RDS)"
  type        = bool
  default     = false
}

resource "aws_security_group_rule" "rds_egress_conditional" {
  count = var.create_security_group && var.enable_egress ? 1 : 0
  
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS for AWS services (if needed)"
  security_group_id = aws_security_group.rds[0].id
}

# ============================================
# 3. 보안 그룹 규칙 감사 로그
# ============================================

# 보안 그룹 변경 사항을 CloudTrail로 추적
# (별도 CloudTrail 설정 필요)

# ============================================
# 4. 네트워크 ACL 추가 보호 (선택적)
# ============================================

# VPC 레벨에서 추가 보호 계층
# 필요시 별도 모듈로 구현
