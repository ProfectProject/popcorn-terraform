# ElastiCache CloudWatch 모니터링 설정

# CloudWatch 알람 - 높은 CPU 사용률
resource "aws_cloudwatch_metric_alarm" "cache_cpu_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-cache-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ElastiCache CPU utilization"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${local.replication_group_id}-001"
  }

  tags = var.tags
}

# CloudWatch 알람 - 높은 메모리 사용률
resource "aws_cloudwatch_metric_alarm" "cache_memory_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-cache-high-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "100000000" # 100MB
  alarm_description   = "This metric monitors ElastiCache available memory"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${local.replication_group_id}-001"
  }

  tags = var.tags
}

# CloudWatch 알람 - 연결 수 모니터링
resource "aws_cloudwatch_metric_alarm" "cache_connections_high" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-cache-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors ElastiCache connection count"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${local.replication_group_id}-001"
  }

  tags = var.tags
}

# CloudWatch 알람 - 캐시 히트율 모니터링
resource "aws_cloudwatch_metric_alarm" "cache_hit_rate_low" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.name}-cache-low-hit-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CacheHitRate"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.8"
  alarm_description   = "This metric monitors ElastiCache hit rate"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${local.replication_group_id}-001"
  }

  tags = var.tags
}