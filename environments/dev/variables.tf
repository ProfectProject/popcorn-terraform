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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# VPC Configuration - 단일 AZ
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"  # dev 환경용 별도 CIDR
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.1.1.0/24"]  # 1개만
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets"
  type        = list(string)
  default     = ["10.1.11.0/24"]  # 1개만
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets"
  type        = list(string)
  default     = ["10.1.21.0/24"]  # 1개만
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = false  # 개발환경에서는 비용 절감을 위해 비활성화
}

# ALB Configuration
variable "certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
}

# Aurora Configuration - 최소 사양
variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.t4g.medium"  # 더 작은 인스턴스
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 1  # Writer만 (Reader 없음)
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "goorm_popcorn_dev"
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

# ElastiCache Configuration - 최소 사양
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"  # 가장 작은 인스턴스
}

variable "elasticache_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

# ECR Configuration
variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

# ECS Services Configuration - 개발용 최소 사양
variable "ecs_services" {
  description = "Configuration for ECS services"
  type = map(object({
    cpu                   = number
    memory               = number
    desired_count        = number
    min_capacity         = number
    max_capacity         = number
    cpu_target_value     = number
    memory_target_value  = number
    environment_variables = list(object({
      name  = string
      value = string
    }))
  }))
  
  default = {
    "api-gateway" = {
      cpu                   = 256      # 최소 CPU
      memory               = 512      # 최소 메모리
      desired_count        = 1        # 1개만
      min_capacity         = 1
      max_capacity         = 2        # 최대 2개
      cpu_target_value     = 80       # 높은 임계값
      memory_target_value  = 85
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "DEBUG"
        }
      ]
    }
    "user-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 2
      cpu_target_value     = 80
      memory_target_value  = 85
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "DEBUG"
        }
      ]
    }
    "store-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 2
      cpu_target_value     = 80
      memory_target_value  = 85
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "DEBUG"
        }
      ]
    }
    "order-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 2
      cpu_target_value     = 80
      memory_target_value  = 85
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "DEBUG"
        }
      ]
    }
    "payment-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 2
      cpu_target_value     = 80
      memory_target_value  = 85
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "DEBUG"
        }
      ]
    }
    "qr-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 2
      cpu_target_value     = 80
      memory_target_value  = 85
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "DEBUG"
        }
      ]
    }
  }
}