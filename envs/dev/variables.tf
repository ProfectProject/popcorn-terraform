variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# VPC 변수
variable "vpc_name" {
  description = "VPC 이름"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "public_subnets" {
  description = "Public 서브넷 목록"
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "private_subnets" {
  description = "Private App 서브넷 목록"
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "data_subnets" {
  description = "Private Data 서브넷 목록"
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "enable_nat" {
  description = "NAT Gateway 활성화 여부"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "단일 NAT Gateway 사용 여부 (비용 절감)"
  type        = bool
  default     = true # Dev: 단일 NAT Gateway
}

# Public ALB 설정 (Frontend 서비스용)
variable "public_alb_name" {
  description = "Public ALB 이름"
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
}

variable "public_alb_health_check_path" {
  description = "Public ALB 헬스체크 경로"
  type        = string
  default     = "/actuator/health"
}

# Management ALB 설정 (Kafka, ArgoCD, Grafana용)
variable "management_alb_name" {
  description = "Management ALB 이름"
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
}

variable "management_alb_health_check_path" {
  description = "Management ALB 헬스체크 경로"
  type        = string
  default     = "/health"
}

# Management ALB 화이트리스트 IP
variable "whitelist_ips" {
  description = "Management ALB 접근 허용 IP 목록 (CIDR 형식)"
  type        = list(string)
  default     = []
}

# ElastiCache 변수
variable "elasticache_name" {
  description = "ElastiCache 클러스터 이름"
  type        = string
}

variable "elasticache_node_type" {
  description = "ElastiCache 노드 타입"
  type        = string
  default     = "cache.t4g.micro" # Dev: 최소 인스턴스
}

variable "elasticache_engine_version" {
  description = "Valkey 엔진 버전"
  type        = string
  default     = "8.0"
}

variable "elasticache_num_cache_clusters" {
  description = "ElastiCache 클러스터 수"
  type        = number
  default     = 1 # Dev: 단일 노드
}

variable "elasticache_automatic_failover" {
  description = "자동 장애조치 활성화 여부"
  type        = bool
  default     = false # Dev: 비활성화
}

variable "elasticache_multi_az_enabled" {
  description = "Multi-AZ 활성화 여부"
  type        = bool
  default     = false # Dev: 단일 AZ
}

# RDS 변수
variable "rds_identifier" {
  description = "RDS 인스턴스 식별자"
  type        = string
}

variable "rds_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t4g.micro" # Dev: 최소 인스턴스
}

variable "rds_allocated_storage" {
  description = "RDS 할당 스토리지 (GB)"
  type        = number
  default     = 20 # Dev: 최소 스토리지
}

variable "rds_engine_version" {
  description = "PostgreSQL 엔진 버전"
  type        = string
  default     = "16.1"
}

variable "rds_multi_az" {
  description = "Multi-AZ 활성화 여부"
  type        = bool
  default     = false # Dev: 단일 AZ
}

variable "rds_backup_retention_period" {
  description = "백업 보존 기간 (일)"
  type        = number
  default     = 1 # Dev: 1일
}

variable "rds_backup_window" {
  description = "백업 시간대"
  type        = string
  default     = "02:00-04:00"
}

variable "rds_maintenance_window" {
  description = "유지보수 시간대"
  type        = string
  default     = "sun:04:00-sun:06:00"
}

variable "rds_performance_insights_enabled" {
  description = "Performance Insights 활성화 여부"
  type        = bool
  default     = false # Dev: 비활성화
}

# IAM 변수
variable "iam_name" {
  description = "IAM 역할 이름 접두사"
  type        = string
}

# EKS 변수
variable "eks_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "eks_cluster_version" {
  description = "Kubernetes 버전"
  type        = string
  default     = "1.34"
}

variable "eks_node_instance_types" {
  description = "EKS 노드 인스턴스 타입"
  type        = list(string)
  default     = ["t3.medium"] # Dev: 단일 인스턴스 타입
}

variable "eks_node_capacity_type" {
  description = "EKS 노드 용량 타입 (ON_DEMAND/SPOT)"
  type        = string
  default     = "ON_DEMAND" # Dev: ON_DEMAND
}

variable "eks_node_min_size" {
  description = "EKS 노드 최소 크기"
  type        = number
  default     = 2 # Dev: 최소 2개
}

variable "eks_node_max_size" {
  description = "EKS 노드 최대 크기"
  type        = number
  default     = 5 # Dev: 최대 5개
}

variable "eks_node_desired_size" {
  description = "EKS 노드 희망 크기"
  type        = number
  default     = 2 # Dev: 2개
}

# 공통 태그
variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "goorm-popcorn"
    ManagedBy   = "terraform"
  }
}
