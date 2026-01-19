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
  default     = "staging"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private app subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

# ALB Configuration
variable "certificate_arn" {
  description = "ARN of the SSL certificate"
  type        = string
}

# Aurora Configuration
variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "aurora_instance_class" {
  description = "Instance class for Aurora instances"
  type        = string
  default     = "db.r6g.large"
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances"
  type        = number
  default     = 2
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

# ElastiCache Configuration
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t4g.micro"
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

# ECS Services Configuration - 스테이징용 중간 사양
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
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 3        # dev보다 높음
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "staging"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "INFO"
        }
      ]
    }
    "user-service" = {
      cpu                   = 512      # dev보다 높은 사양
      memory               = 1024
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 8        # dev보다 높음
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "staging"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "INFO"
        }
      ]
    }
    "store-service" = {
      cpu                   = 512
      memory               = 1024
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 5
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "staging"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "INFO"
        }
      ]
    }
    "order-service" = {
      cpu                   = 512
      memory               = 1024
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 8
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "staging"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "INFO"
        }
      ]
    }
    "payment-service" = {
      cpu                   = 512
      memory               = 1024
      desired_count        = 2        # 중요 서비스는 2개
      min_capacity         = 2
      max_capacity         = 10
      cpu_target_value     = 60       # 더 보수적
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "staging"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "INFO"
        }
      ]
    }
    "qr-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 5
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "staging"
        },
        {
          name  = "LOGGING_LEVEL_ROOT"
          value = "INFO"
        }
      ]
    }
  }
}