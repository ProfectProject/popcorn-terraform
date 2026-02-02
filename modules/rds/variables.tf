# RDS PostgreSQL Module Variables

variable "identifier" {
  description = "The name of the RDS instance"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

# Engine Configuration
variable "engine" {
  description = "The database engine"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "The engine version to use"
  type        = string
  default     = "16.4"
}

variable "parameter_group_family" {
  description = "The DB parameter group family"
  type        = string
  default     = "postgres16"
}

variable "major_engine_version" {
  description = "The major engine version for option group"
  type        = string
  default     = "16"
}

# Instance Configuration
variable "instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t4g.micro"
}

# Storage Configuration
variable "allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "The upper limit to which Amazon RDS can automatically scale the storage"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "One of standard (magnetic), gp2 (general purpose SSD), or io1 (provisioned IOPS SSD)"
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key"
  type        = string
  default     = null
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 7
}

# Database Configuration
variable "database_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "popcorn"
}

variable "master_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "postgres"
}

variable "master_password" {
  description = "Password for the master DB user"
  type        = string
  sensitive   = true
}

variable "database_port" {
  description = "The port on which the DB accepts connections"
  type        = number
  default     = 5432
}

# Network Configuration
variable "subnet_ids" {
  description = "A list of VPC subnet IDs"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "List of VPC security groups to associate"
  type        = list(string)
}

variable "publicly_accessible" {
  description = "Bool to control if instance is publicly accessible"
  type        = bool
  default     = false
}

# High Availability Configuration
variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ"
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "The AZ for the RDS instance (only for single-AZ)"
  type        = string
  default     = null
}

# Backup Configuration
variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 1
}

variable "backup_window" {
  description = "The daily time range (in UTC) during which automated backups are created"
  type        = string
  default     = "03:00-04:00"
}

variable "copy_tags_to_snapshot" {
  description = "On delete, copy all Instance tags to the final snapshot"
  type        = bool
  default     = true
}

variable "delete_automated_backups" {
  description = "Specifies whether to remove automated backups immediately after the DB instance is deleted"
  type        = bool
  default     = true
}

# Maintenance Configuration
variable "maintenance_window" {
  description = "The window to perform maintenance in"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically"
  type        = bool
  default     = true
}

# Parameter Configuration
variable "db_parameters" {
  description = "A list of DB parameters to apply"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    },
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"
    },
    {
      name  = "log_connections"
      value = "1"
    },
    {
      name  = "log_disconnections"
      value = "1"
    }
  ]
}

variable "create_option_group" {
  description = "Whether to create an option group"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "monitoring_interval" {
  description = "The interval for collecting enhanced monitoring metrics"
  type        = number
  default     = 60
}

variable "monitoring_role_arn" {
  description = "The ARN for the IAM role for enhanced monitoring"
  type        = string
  default     = null
}

# Performance Insights
variable "performance_insights_enabled" {
  description = "Specifies whether Performance Insights are enabled"
  type        = bool
  default     = true
}

variable "performance_insights_kms_key_id" {
  description = "The ARN for the KMS key to encrypt Performance Insights data"
  type        = string
  default     = null
}

variable "performance_insights_retention_period" {
  description = "The amount of time in days to retain Performance Insights data"
  type        = number
  default     = 7
}

# Deletion Protection
variable "deletion_protection" {
  description = "The database can't be deleted when this value is set to true"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted"
  type        = bool
  default     = false
}

# CloudWatch Logs
variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to cloudwatch"
  type        = list(string)
  default     = ["postgresql"]
}

variable "cloudwatch_log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Apply Changes
variable "apply_immediately" {
  description = "Specifies whether any database modifications are applied immediately"
  type        = bool
  default     = false
}

# Read Replica Configuration
variable "create_read_replica" {
  description = "Whether to create read replicas"
  type        = bool
  default     = false
}

variable "read_replica_count" {
  description = "Number of read replicas to create"
  type        = number
  default     = 1
}

variable "read_replica_instance_class" {
  description = "The instance class for read replicas"
  type        = string
  default     = null
}

variable "read_replica_availability_zones" {
  description = "List of availability zones for read replicas"
  type        = list(string)
  default     = null
}

# Tags
variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}