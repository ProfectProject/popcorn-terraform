terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "goorm-popcorn-terraform-state-global"
    key    = "global/route53/terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Type      = "Global"
    }
  }
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name = "${var.project_name}-hosted-zone"
  }
}

# ACM Certificate
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

# Route 53 Records for ACM Certificate Validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# Route 53 Health Check (for production ALB)
resource "aws_route53_health_check" "prod_alb" {
  count = var.enable_health_checks ? 1 : 0

  fqdn                            = var.prod_alb_dns_name
  port                            = 443
  type                            = "HTTPS_STR_MATCH"
  resource_path                   = "/actuator/health"
  failure_threshold               = "3"
  request_interval                = "30"
  search_string                   = "UP"
  cloudwatch_logs_region          = var.aws_region
  cloudwatch_alarm_region         = var.aws_region
  insufficient_data_health_status = "Failure"

  tags = {
    Name = "${var.project_name}-prod-health-check"
  }
}

# Route 53 Records
resource "aws_route53_record" "prod" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  dynamic "alias" {
    for_each = var.prod_alb_dns_name != "" ? [1] : []
    content {
      name                   = var.prod_alb_dns_name
      zone_id                = var.prod_alb_zone_id
      evaluate_target_health = true
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = var.enable_blue_green ? [1] : []
    content {
      weight = var.prod_weight
    }
  }

  set_identifier = var.enable_blue_green ? "prod" : null
  health_check_id = var.enable_health_checks && length(aws_route53_health_check.prod_alb) > 0 ? aws_route53_health_check.prod_alb[0].id : null
}

resource "aws_route53_record" "staging" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "staging.${var.domain_name}"
  type    = "A"

  dynamic "alias" {
    for_each = var.staging_alb_dns_name != "" ? [1] : []
    content {
      name                   = var.staging_alb_dns_name
      zone_id                = var.staging_alb_zone_id
      evaluate_target_health = true
    }
  }
}

# API subdomain
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.prod_alb_dns_name
    zone_id                = var.prod_alb_zone_id
    evaluate_target_health = true
  }
}