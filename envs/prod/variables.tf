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

variable "enable_nat" {
  type    = bool
  default = false
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

# Public ALB 설정 (Frontend 서비스용)
variable "public_alb_name" {
  type = string
}

variable "public_alb_target_group_name" {
  type = string
}

variable "public_alb_target_group_port" {
  type    = number
  default = 8080
}

variable "public_alb_health_check_path" {
  type    = string
  default = "/actuator/health"
}

# Management ALB 설정 (Kafka, ArgoCD, Grafana용)
variable "management_alb_name" {
  type = string
}

variable "management_alb_target_group_name" {
  type = string
}

variable "management_alb_target_group_port" {
  type    = number
  default = 8080
}

variable "management_alb_health_check_path" {
  type    = string
  default = "/health"
}

# Management ALB 화이트리스트 IP
variable "whitelist_ips" {
  description = "Management ALB 접근 허용 IP 목록 (CIDR 형식)"
  type        = list(string)
  default     = []
}

variable "elasticache_name" {
  type = string
}

variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.small"
}

variable "elasticache_engine_version" {
  description = "Valkey engine version"
  type        = string
  default     = "8.0"
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
  default = ["t3.medium", "t3.large"]
}

variable "eks_node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}

variable "eks_node_min_size" {
  type    = number
  default = 3
}

variable "eks_node_max_size" {
  type    = number
  default = 20
}

variable "eks_node_desired_size" {
  type    = number
  default = 6
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

# RDS 관련 변수
variable "rds_name" {
  type = string
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "rds_allocated_storage" {
  type    = number
  default = 100
}

variable "rds_backup_retention_period" {
  type    = number
  default = 7
}

variable "rds_engine_version" {
  type    = string
  default = "18.1"
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
