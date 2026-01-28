# VPC Flow Logs 설정

# CloudWatch 로그 그룹 for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.name}"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-flow-logs"
  })
}

# IAM 역할 for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.name}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-flow-logs"
  })
}

# CloudWatch 메트릭 필터 - 거부된 트래픽
resource "aws_cloudwatch_log_metric_filter" "rejected_traffic" {
  count = var.enable_flow_logs ? 1 : 0

  name           = "${var.name}-rejected-traffic"
  log_group_name = aws_cloudwatch_log_group.vpc_flow_logs.name
  pattern        = "[version, account_id, interface_id, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, windowstart, windowend, action=\"REJECT\", flowlogstatus]"

  metric_transformation {
    name      = "RejectedTrafficCount"
    namespace = "VPC/FlowLogs"
    value     = "1"
  }
}

# CloudWatch 알람 - 높은 거부된 트래픽
resource "aws_cloudwatch_metric_alarm" "high_rejected_traffic" {
  count = var.enable_flow_logs && var.sns_topic_arn != null ? 1 : 0

  alarm_name          = "${var.name}-high-rejected-traffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RejectedTrafficCount"
  namespace           = "VPC/FlowLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors rejected traffic in VPC"
  alarm_actions       = [var.sns_topic_arn]

  tags = var.tags
}