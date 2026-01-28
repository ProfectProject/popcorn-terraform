variable "name" {
  description = "Name prefix for monitoring resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_sns_alerts" {
  description = "Enable SNS topic and email alerts"
  type        = bool
  default     = false
}

variable "alert_email_addresses" {
  description = "Email addresses to receive alerts (only used if enable_sns_alerts is true)"
  type        = list(string)
  default     = []
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for metrics"
  type        = string
}

variable "rds_instance_id" {
  description = "RDS instance identifier"
  type        = string
}

variable "elasticache_cluster_id" {
  description = "ElastiCache cluster ID"
  type        = string
}