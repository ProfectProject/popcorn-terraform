output "cluster_arn" {
  description = "ARN of the MSK Serverless cluster"
  value       = aws_msk_serverless_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the MSK Serverless cluster"
  value       = aws_msk_serverless_cluster.main.cluster_name
}

output "bootstrap_brokers_sasl_iam" {
  description = "Bootstrap brokers for SASL/IAM authentication"
  value       = aws_msk_serverless_cluster.main.bootstrap_brokers_sasl_iam
}

output "msk_access_policy_arn" {
  description = "ARN of the MSK access policy"
  value       = aws_iam_policy.msk_access.arn
}

output "msk_config_secret_arn" {
  description = "ARN of the MSK configuration secret"
  value       = aws_secretsmanager_secret.msk_config.arn
}