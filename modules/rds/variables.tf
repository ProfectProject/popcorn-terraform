variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "private_data_subnet_ids" {
  description = "IDs of the private data subnets"
  type        = list(string)
}

variable "aurora_security_group_id" {
  description = "ID of the Aurora security group"
  type        = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.r6g.large"
}

variable "instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 3
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "goorm_popcorn_db"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
  default     = null
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds"
  type        = number
  default     = 60
}

variable "enable_autoscaling" {
  description = "Enable Aurora Auto Scaling"
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum number of Aurora read replicas"
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of Aurora read replicas"
  type        = number
  default     = 10
}

variable "autoscaling_target_cpu" {
  description = "Target CPU utilization for autoscaling"
  type        = number
  default     = 70
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}