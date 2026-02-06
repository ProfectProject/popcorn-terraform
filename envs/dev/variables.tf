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
  default = "/actuator/health"
}

variable "elasticache_name" {
  type = string
}

variable "elasticache_node_type" {
  type    = string
  default = "cache.t4g.micro"
}

variable "elasticache_engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "8.0"
}

variable "elasticache_num_cache_clusters" {
  type    = number
  default = 1
}

variable "elasticache_automatic_failover" {
  type    = bool
  default = false
}

variable "elasticache_multi_az_enabled" {
  type    = bool
  default = false
}

# IAM 관련 변수
variable "iam_name" {
  type = string
}

# RDS 관련 변수
variable "rds_name" {
  type = string
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_backup_retention_period" {
  type    = number
  default = 1
}

variable "rds_engine_version" {
  type    = string
  default = "16.4"
}

# EKS 관련 변수
variable "eks_name" {
  type = string
}

variable "eks_cluster_version" {
  type    = string
  default = "1.35"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "eks_node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "eks_node_min_size" {
  type    = number
  default = 1
}

variable "eks_node_max_size" {
  type    = number
  default = 5
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
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
  default     = "dev-latest"
}

# 공통 태그
variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Project     = "goorm-popcorn"
    ManagedBy   = "terraform"
  }
}
