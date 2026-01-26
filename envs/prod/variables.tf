variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "private_subnets" {
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "data_subnets" {
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "sg_name" {
  type = string
}

variable "enable_nat" {
  type    = bool
  default = false
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "alb_name" {
  type = string
}

variable "alb_target_group_name" {
  type = string
}

variable "alb_target_group_port" {
  type    = number
  default = 8080
}

variable "alb_health_check_path" {
  type    = string
  default = "/health"
}

variable "elasticache_name" {
  type = string
}

variable "elasticache_node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "elasticache_engine_version" {
  type    = string
  default = "7.0"
}

variable "elasticache_num_cache_clusters" {
  type    = number
  default = 2
}

variable "elasticache_automatic_failover" {
  type    = bool
  default = true
}

variable "elasticache_multi_az_enabled" {
  type    = bool
  default = true
}
# IAM 관련 변수
variable "iam_name" {
  type = string
}

# Aurora 관련 변수
variable "aurora_name" {
  type = string
}

variable "aurora_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "aurora_backup_retention_period" {
  type    = number
  default = 7
}

variable "aurora_preferred_backup_window" {
  type    = string
  default = "03:00-04:00"
}

# ECS 관련 변수
variable "ecs_name" {
  type = string
}

variable "ecr_repository_url" {
  type = string
}

variable "ecr_repositories" {
  description = "Map of service names to ECR repository URLs"
  type        = map(string)
  default     = {}
}

variable "image_tag" {
  description = "Docker image tag to use"
  type        = string
  default     = "latest"
}

variable "ecs_log_retention_days" {
  type    = number
  default = 30
}

# CloudMap 관련 변수
variable "cloudmap_name" {
  type = string
}

variable "cloudmap_namespace" {
  type    = string
  default = "goormpopcorn.local"
}

# EC2 Kafka 관련 변수
variable "ec2_kafka_name" {
  type = string
}

variable "ec2_kafka_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ec2_kafka_key_name" {
  type = string
}

variable "ec2_kafka_node_count" {
  type    = number
  default = 3
}

# 공통 태그
variable "tags" {
  type = map(string)
  default = {
    Environment = "prod"
    Project     = "goorm-popcorn"
    ManagedBy   = "terraform"
  }
}