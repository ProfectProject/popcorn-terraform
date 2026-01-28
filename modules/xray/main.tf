# X-Ray 분산 추적 설정

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# X-Ray 서비스 맵 설정
resource "aws_xray_sampling_rule" "main" {
  rule_name      = "${var.name}-sampling-rule"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = var.tags
}

# X-Ray 암호화 설정
resource "aws_xray_encryption_config" "main" {
  type   = "KMS"
  key_id = var.kms_key_id != null ? var.kms_key_id : "alias/aws/xray"
}

# CloudWatch Insights 쿼리 for X-Ray 분석
resource "aws_cloudwatch_query_definition" "xray_errors" {
  name = "${var.name}-xray-errors"

  log_group_names = var.log_group_names

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)
EOF
}

resource "aws_cloudwatch_query_definition" "xray_latency" {
  name = "${var.name}-xray-latency"

  log_group_names = var.log_group_names

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /response_time/
| stats avg(response_time), max(response_time), min(response_time) by bin(5m)
EOF
}