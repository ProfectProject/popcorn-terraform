# RDS PostgreSQL Module Outputs

# RDS Instance Outputs
output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_hosted_zone_id" {
  description = "The canonical hosted zone ID of the DB instance"
  value       = aws_db_instance.main.hosted_zone_id
}

output "db_instance_port" {
  description = "The RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_availability_zone" {
  description = "The availability zone of the RDS instance"
  value       = aws_db_instance.main.availability_zone
}

output "db_instance_multi_az" {
  description = "If the RDS instance is multi AZ enabled"
  value       = aws_db_instance.main.multi_az
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.main.resource_id
}

output "db_instance_status" {
  description = "The RDS instance status"
  value       = aws_db_instance.main.status
}

output "db_instance_engine" {
  description = "The database engine"
  value       = aws_db_instance.main.engine
}

output "db_instance_engine_version" {
  description = "The running version of the database"
  value       = aws_db_instance.main.engine_version_actual
}

output "db_instance_class" {
  description = "The RDS instance class"
  value       = aws_db_instance.main.instance_class
}

# Connection Information
output "db_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${aws_db_instance.main.username}:${var.master_password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = true
}

output "db_jdbc_url" {
  description = "JDBC connection URL"
  value       = "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
}

# Subnet Group
output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "The ARN of the db subnet group"
  value       = aws_db_subnet_group.main.arn
}

# Parameter Group
output "db_parameter_group_id" {
  description = "The db parameter group id"
  value       = aws_db_parameter_group.main.id
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group"
  value       = aws_db_parameter_group.main.arn
}

# Option Group
output "db_option_group_id" {
  description = "The db option group id"
  value       = var.create_option_group ? aws_db_option_group.main[0].id : null
}

output "db_option_group_arn" {
  description = "The ARN of the db option group"
  value       = var.create_option_group ? aws_db_option_group.main[0].arn : null
}

# KMS Key
output "kms_key_id" {
  description = "The globally unique identifier for the key"
  value       = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.rds[0].key_id
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.rds[0].arn
}

# Read Replicas
output "read_replica_ids" {
  description = "List of read replica instance IDs"
  value       = var.create_read_replica ? aws_db_instance.read_replica[*].id : []
}

output "read_replica_endpoints" {
  description = "List of read replica endpoints"
  value       = var.create_read_replica ? aws_db_instance.read_replica[*].endpoint : []
}

output "read_replica_arns" {
  description = "List of read replica ARNs"
  value       = var.create_read_replica ? aws_db_instance.read_replica[*].arn : []
}

# CloudWatch Log Groups
output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log groups"
  value = {
    for log_type in var.enabled_cloudwatch_logs_exports :
    log_type => aws_cloudwatch_log_group.postgresql[log_type].name
  }
}

# Environment-specific outputs
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "is_multi_az" {
  description = "Whether this is a Multi-AZ deployment"
  value       = var.multi_az
}

output "backup_retention_period" {
  description = "The backup retention period"
  value       = var.backup_retention_period
}

output "backup_window" {
  description = "The backup window"
  value       = var.backup_window
}

output "maintenance_window" {
  description = "The maintenance window"
  value       = var.maintenance_window
}