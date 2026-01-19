output "cluster_identifier" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.main.cluster_identifier
}

output "cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.main.port
}

output "cluster_database_name" {
  description = "Aurora cluster database name"
  value       = aws_rds_cluster.main.database_name
}

output "cluster_master_username" {
  description = "Aurora cluster master username"
  value       = aws_rds_cluster.main.master_username
  sensitive   = true
}

output "master_password_secret_arn" {
  description = "ARN of the master password secret"
  value       = aws_secretsmanager_secret.db_master_password.arn
}

output "instance_endpoints" {
  description = "Aurora instance endpoints"
  value       = aws_rds_cluster_instance.cluster_instances[*].endpoint
}

output "instance_identifiers" {
  description = "Aurora instance identifiers"
  value       = aws_rds_cluster_instance.cluster_instances[*].identifier
}