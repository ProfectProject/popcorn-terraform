output "sampling_rule_arn" {
  description = "X-Ray sampling rule ARN"
  value       = aws_xray_sampling_rule.main.arn
}

output "encryption_config" {
  description = "X-Ray encryption configuration"
  value       = aws_xray_encryption_config.main
}