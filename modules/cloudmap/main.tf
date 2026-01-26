# CloudMap Service Discovery Module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  base_tags = merge({ Name = var.name }, var.tags)
}

# Private DNS Namespace for Service Discovery
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.namespace_name
  description = "Service discovery namespace for ${var.name}"
  vpc         = var.vpc_id

  tags = merge(local.base_tags, {
    Name = "${var.name}-service-discovery"
  })
}

# Service Discovery Services
resource "aws_service_discovery_service" "services" {
  for_each = toset(var.service_names)

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = var.dns_ttl
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  # health_check_grace_period_seconds = var.health_check_grace_period  # Invalid argument removed

  tags = merge(local.base_tags, {
    Name    = "${var.name}-${each.key}-service"
    Service = each.key
  })
}