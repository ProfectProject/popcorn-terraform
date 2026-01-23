# RDS PostgreSQL Module Outputs

output "instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.identifier
}

output "instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "master_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "master_password_secret_arn" {
  description = "ARN of the master password secret in Secrets Manager"
  value       = aws_secretsmanager_secret.db_master_password.arn
}

output "master_password_secret_name" {
  description = "Name of the master password secret in Secrets Manager"
  value       = aws_secretsmanager_secret.db_master_password.name
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}

output "security_group_id" {
  description = "Security group ID used by RDS instance"
  value       = var.security_group_id
}