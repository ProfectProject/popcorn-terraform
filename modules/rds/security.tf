# Security Group for RDS
resource "aws_security_group" "rds" {
  count = var.create_security_group ? 1 : 0

  name_prefix = "${var.identifier}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS PostgreSQL ${var.identifier}"

  tags = merge(var.tags, {
    Name = "${var.identifier}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# PostgreSQL 접근 규칙
resource "aws_security_group_rule" "rds_ingress" {
  for_each = var.create_security_group ? var.allowed_security_groups : {}

  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "PostgreSQL from ${each.key}"
  security_group_id        = aws_security_group.rds[0].id
}

# VPC CIDR 접근 (관리용)
resource "aws_security_group_rule" "rds_ingress_vpc" {
  count = var.create_security_group && var.allow_vpc_cidr ? 1 : 0

  type              = "ingress"
  from_port         = var.database_port
  to_port           = var.database_port
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  description       = "PostgreSQL from VPC"
  security_group_id = aws_security_group.rds[0].id
}

# Egress 규칙
resource "aws_security_group_rule" "rds_egress" {
  count = var.create_security_group ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
  security_group_id = aws_security_group.rds[0].id
}
