variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "goorm-popcorn"
}

variable "domain_name" {
  description = "Domain name"
  type        = string
  default     = "goormpopcron.shop"
}

variable "prod_alb_dns_name" {
  description = "DNS name of the production ALB"
  type        = string
  default     = ""
}

variable "prod_alb_zone_id" {
  description = "Zone ID of the production ALB"
  type        = string
  default     = ""
}

variable "staging_alb_dns_name" {
  description = "DNS name of the staging ALB"
  type        = string
  default     = ""
}

variable "staging_alb_zone_id" {
  description = "Zone ID of the staging ALB"
  type        = string
  default     = ""
}

variable "enable_health_checks" {
  description = "Enable Route 53 health checks"
  type        = bool
  default     = false
}

variable "enable_blue_green" {
  description = "Enable blue/green deployment with weighted routing"
  type        = bool
  default     = false
}

variable "prod_weight" {
  description = "Weight for production environment in weighted routing"
  type        = number
  default     = 100
}