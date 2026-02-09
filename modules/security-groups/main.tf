# Security Groups 모듈 메인 설정

locals {
  common_tags = merge(
    var.tags,
    {
      Module      = "security-groups"
      Environment = var.environment
    }
  )
}

# ============================================
# Public ALB Security Group
# ============================================

resource "aws_security_group" "public_alb" {
  name        = "popcorn-${var.environment}-public-alb-sg"
  description = "Public ALB 보안 그룹 - 외부 사용자 접근용 (Frontend)"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "popcorn-${var.environment}-public-alb-sg"
      Type = "public-alb"
    }
  )
}

# Public ALB Ingress: HTTP (80)
resource "aws_security_group_rule" "public_alb_ingress_http" {
  type              = "ingress"
  security_group_id = aws_security_group.public_alb.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP from internet"
}

# Public ALB Ingress: HTTPS (443)
resource "aws_security_group_rule" "public_alb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.public_alb.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS from internet"
}

# Public ALB Egress: 모든 트래픽 (EKS Node로)
resource "aws_security_group_rule" "public_alb_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.public_alb.id
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all ports to EKS Node"
}

# ============================================
# Management ALB Security Group
# ============================================

resource "aws_security_group" "management_alb" {
  name        = "popcorn-${var.environment}-management-alb-sg"
  description = "Management ALB 보안 그룹 - 관리 도구 접근용 (Kafka, ArgoCD, Grafana)"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "popcorn-${var.environment}-management-alb-sg"
      Type = "management-alb"
    }
  )
}

# Management ALB Ingress: HTTP (80) - 화이트리스트 IP만
resource "aws_security_group_rule" "management_alb_ingress_http" {
  type              = "ingress"
  security_group_id = aws_security_group.management_alb.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.whitelist_ips
  description       = "Allow HTTP from whitelist IPs"
}

# Management ALB Ingress: HTTPS (443) - 화이트리스트 IP만
resource "aws_security_group_rule" "management_alb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.management_alb.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.whitelist_ips
  description       = "Allow HTTPS from whitelist IPs"
}

# Management ALB Egress: 모든 트래픽 (EKS Node로)
resource "aws_security_group_rule" "management_alb_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.management_alb.id
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all ports to EKS Node"
}

# ============================================
# EKS Node Security Group Rules (선택적)
# ============================================
# 참고: EKS 모듈에서 이미 생성된 보안 그룹에 규칙 추가
# eks_node_security_group_id가 제공된 경우에만 생성

# EKS Node Ingress: ALB에서 모든 포트 접근 허용
resource "aws_security_group_rule" "eks_node_ingress_from_public_alb" {
  count                    = var.eks_node_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  security_group_id        = var.eks_node_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.public_alb.id
  description              = "Allow all ports from Public ALB to EKS Node"
}

resource "aws_security_group_rule" "eks_node_ingress_from_management_alb" {
  count                    = var.eks_node_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  security_group_id        = var.eks_node_security_group_id
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.management_alb.id
  description              = "Allow all ports from Management ALB to EKS Node"
}

# ============================================
# RDS Security Group
# ============================================

resource "aws_security_group" "rds" {
  name        = "popcorn-${var.environment}-rds-sg"
  description = "RDS PostgreSQL 보안 그룹 - EKS Node에서만 접근 허용"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "popcorn-${var.environment}-rds-sg"
      Type = "rds"
    }
  )
}

# RDS Ingress: PostgreSQL (5432) - EKS Node에서만
resource "aws_security_group_rule" "rds_ingress_from_eks" {
  count                    = var.eks_node_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.eks_node_security_group_id
  description              = "Allow PostgreSQL from EKS Node"
}

# RDS Egress: 없음 (기본적으로 아웃바운드 트래픽 불필요)

# ============================================
# ElastiCache Security Group
# ============================================

resource "aws_security_group" "elasticache" {
  name        = "popcorn-${var.environment}-elasticache-sg"
  description = "ElastiCache Valkey 보안 그룹 - EKS Node에서만 접근 허용"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "popcorn-${var.environment}-elasticache-sg"
      Type = "elasticache"
    }
  )
}

# ElastiCache Ingress: Redis/Valkey (6379) - EKS Node에서만
resource "aws_security_group_rule" "elasticache_ingress_from_eks" {
  count                    = var.eks_node_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  security_group_id        = aws_security_group.elasticache.id
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.eks_node_security_group_id
  description              = "Allow Redis/Valkey from EKS Node"
}

# ElastiCache Egress: 없음 (기본적으로 아웃바운드 트래픽 불필요)
