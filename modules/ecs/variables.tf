# ECS Fargate Module Variables

variable "name" {
  description = "Base name for ECS resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  type        = string
}

variable "alb_target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
  default     = null
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener"
  type        = string
  default     = null
}

variable "ecr_repository_url" {
  description = "Base URL of the ECR repository"
  type        = string
}

variable "ecr_repositories" {
  description = "Map of service names to ECR repository URLs"
  type        = map(string)
  default     = {}
}

variable "image_tag" {
  description = "Docker image tag to use (e.g., latest, dev-latest, feature-branch-abc12345)"
  type        = string
  default     = "latest"
}

variable "service_discovery_service_arns" {
  description = "Map of service discovery service ARNs"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "service_names" {
  description = "List of service names"
  type        = list(string)
  default     = ["api-gateway", "user-service", "store-service", "order-service", "payment-service", "checkin-service", "order-query"]
}

variable "services" {
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
      max_capacity         = 2
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        }
      ]
    }
    "user-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 3
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        }
      ]
    }
    "store-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 3
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        }
      ]
    }
    "order-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 3
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        }
      ]
    }
    "payment-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 3
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        }
      ]
    }
    "checkin-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 2
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        }
      ]
    }
    "order-query" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 1
      min_capacity         = 1
      max_capacity         = 2
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "dev"
        }
      ]
    }
  }
}

variable "elasticache_primary_endpoint" {
  description = "ElastiCache primary endpoint"
  type        = string
  default     = null
}

variable "elasticache_reader_endpoint" {
  description = "ElastiCache reader endpoint"
  type        = string
  default     = null
}

variable "database_endpoint" {
  description = "Database endpoint (RDS or Aurora)"
  type        = string
  default     = null
}

variable "database_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "goorm_popcorn_db"
}

variable "database_secret_arn" {
  description = "ARN of the database password secret"
  type        = string
  default     = null
}

variable "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}