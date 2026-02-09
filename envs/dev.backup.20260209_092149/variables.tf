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
  description = "Public ALB 이름 (Frontend 서비스용)"
  type        = string
}

variable "public_alb_target_group_name" {
  description = "Public ALB 타겟 그룹 이름"
  type        = string
}

variable "public_alb_target_group_port" {
  description = "Public ALB 타겟 그룹 포트"
  type        = number
  default     = 8080

  validation {
    condition     = var.public_alb_target_group_port >= 1 && var.public_alb_target_group_port <= 65535
    error_message = "포트는 1-65535 사이여야 합니다."
  }
}

variable "public_alb_health_check_path" {
  description = "Public ALB 헬스체크 경로"
  type        = string
  default     = "/actuator/health"
}

# Management ALB 설정 (Kafka, ArgoCD, Grafana용)
variable "management_alb_name" {
  description = "Management ALB 이름 (관리 도구용)"
  type        = string
}

variable "management_alb_target_group_name" {
  description = "Management ALB 타겟 그룹 이름"
  type        = string
}

variable "management_alb_target_group_port" {
  description = "Management ALB 타겟 그룹 포트"
  type        = number
  default     = 8080

  validation {
    condition     = var.management_alb_target_group_port >= 1 && var.management_alb_target_group_port <= 65535
    error_message = "포트는 1-65535 사이여야 합니다."
  }
}

variable "management_alb_health_check_path" {
  description = "Management ALB 헬스체크 경로"
  type        = string
  default     = "/health"
}

# Management ALB 화이트리스트 IP
variable "whitelist_ips" {
  description = "Management ALB 접근 허용 IP 목록 (CIDR 형식). 보안을 위해 반드시 설정해야 합니다."
  type        = list(string)

  validation {
    condition     = length(var.whitelist_ips) > 0
    error_message = "Management ALB 화이트리스트 IP는 최소 1개 이상 설정해야 합니다. 보안을 위해 0.0.0.0/0은 사용하지 마세요."
  }
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
  description = "RDS 백업 보존 기간 (일). Dev 환경 최소 3일 권장"
  type        = number
  default     = 3

  validation {
    condition     = var.rds_backup_retention_period >= 1 && var.rds_backup_retention_period <= 35
    error_message = "백업 보존 기간은 1-35일 사이여야 합니다."
  }
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
