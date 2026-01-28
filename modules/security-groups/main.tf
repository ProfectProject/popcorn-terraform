locals {
  base_tags = merge({ Name = var.name }, var.tags)
}

resource "aws_security_group" "alb" {
  name                   = "${var.name}-sg-alb"
  description            = "ALB ingress from internet, egress to ECS"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  ingress                = []
  egress                 = []

  tags = merge(local.base_tags, { Name = "${var.name}-sg-alb" })

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

resource "aws_security_group" "ecs" {
  name                   = "${var.name}-sg-ecs"
  description            = "ECS tasks ingress from ALB and ECS, egress to data/messaging"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  ingress                = []
  egress                 = []

  tags = merge(local.base_tags, { Name = "${var.name}-sg-ecs" })

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

resource "aws_security_group" "db" {
  name                   = "${var.name}-sg-db"
  description            = "Aurora ingress from ECS"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  ingress                = []
  egress                 = []

  tags = merge(local.base_tags, { Name = "${var.name}-sg-db" })

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

resource "aws_security_group" "cache" {
  name                   = "${var.name}-sg-cache"
  description            = "ElastiCache ingress from ECS"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  ingress                = []
  egress                 = []

  tags = merge(local.base_tags, { Name = "${var.name}-sg-cache" })

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

resource "aws_security_group" "kafka" {
  name                   = "${var.name}-sg-kafka"
  description            = "MSK ingress from ECS"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true
  ingress                = []
  egress                 = []

  tags = merge(local.base_tags, { Name = "${var.name}-sg-kafka" })

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP from internet"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS from internet"
}

resource "aws_security_group_rule" "alb_egress_ecs" {
  type                     = "egress"
  security_group_id        = aws_security_group.alb.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "ALB to ECS app port"
}

resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "ECS from ALB"
}

resource "aws_security_group_rule" "ecs_ingress_from_ecs" {
  type                     = "ingress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "ECS service-to-service"
}

resource "aws_security_group_rule" "ecs_egress_to_ecs" {
  type                     = "egress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "ECS to ECS app port"
}

resource "aws_security_group_rule" "ecs_egress_https" {
  type              = "egress"
  security_group_id = aws_security_group.ecs.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "ECS to internet HTTPS (via NAT/endpoint)"
}

resource "aws_security_group_rule" "ecs_egress_db" {
  type                     = "egress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db.id
  description              = "ECS to Aurora"
}

resource "aws_security_group_rule" "ecs_egress_cache" {
  type                     = "egress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = var.cache_port
  to_port                  = var.cache_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cache.id
  description              = "ECS to ElastiCache"
}

resource "aws_security_group_rule" "ecs_egress_kafka" {
  for_each                 = { for port in var.kafka_ports : tostring(port) => port }
  type                     = "egress"
  security_group_id        = aws_security_group.ecs.id
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.kafka.id
  description              = "ECS to MSK"
}

resource "aws_security_group_rule" "db_ingress_from_ecs" {
  type                     = "ingress"
  security_group_id        = aws_security_group.db.id
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "Aurora from ECS"
}

resource "aws_security_group_rule" "cache_ingress_from_ecs" {
  type                     = "ingress"
  security_group_id        = aws_security_group.cache.id
  from_port                = var.cache_port
  to_port                  = var.cache_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "ElastiCache from ECS"
}

resource "aws_security_group_rule" "kafka_ingress_from_ecs" {
  for_each                 = { for port in var.kafka_ports : tostring(port) => port }
  type                     = "ingress"
  security_group_id        = aws_security_group.kafka.id
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id
  description              = "MSK from ECS"
}
