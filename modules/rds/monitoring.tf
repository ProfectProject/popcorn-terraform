# SNS Topic for RDS Alarms
resource "aws_sns_topic" "rds_alerts" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  name = "${var.identifier}-rds-alerts"

  tags = merge(var.tags, {
    Name = "${var.identifier}-rds-alerts"
  })
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.identifier}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.rds_alerts[0].arn]
  ok_actions          = [aws_sns_topic.rds_alerts[0].arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-cpu-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.identifier}-rds-database-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_connections_threshold
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = [aws_sns_topic.rds_alerts[0].arn]
  ok_actions          = [aws_sns_topic.rds_alerts[0].arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-connections-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.identifier}-rds-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_free_storage_threshold
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [aws_sns_topic.rds_alerts[0].arn]
  ok_actions          = [aws_sns_topic.rds_alerts[0].arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-storage-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_read_latency" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.identifier}-rds-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_read_latency_threshold
  alarm_description   = "This metric monitors RDS read latency"
  alarm_actions       = [aws_sns_topic.rds_alerts[0].arn]
  ok_actions          = [aws_sns_topic.rds_alerts[0].arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-read-latency-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_write_latency" {
  count = var.create_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.identifier}-rds-write-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_write_latency_threshold
  alarm_description   = "This metric monitors RDS write latency"
  alarm_actions       = [aws_sns_topic.rds_alerts[0].arn]
  ok_actions          = [aws_sns_topic.rds_alerts[0].arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-write-latency-alarm"
  })
}
