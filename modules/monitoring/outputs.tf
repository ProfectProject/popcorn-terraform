output "sns_topic_arn" {
  description = "SNS topic ARN for alerts (null if SNS is disabled)"
  value       = var.enable_sns_alerts ? aws_sns_topic.alerts[0].arn : null
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}