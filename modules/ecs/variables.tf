variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "IDs of the private app subnets"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID of the ECS security group"
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
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository"
  type        = string
}

variable "service_discovery_service_arns" {
  description = "ARNs of the service discovery services"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "service_names" {
  description = "List of service names"
  type        = list(string)
  default     = ["api-gateway", "user-service", "store-service", "order-service", "payment-service", "qr-service"]
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
      desired_count        = 2
      min_capacity         = 2
      max_capacity         = 4
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]
    }
    "user-service" = {
      cpu                   = 512
      memory               = 1024
      desired_count        = 2
      min_capacity         = 2
      max_capacity         = 20
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]
    }
    "store-service" = {
      cpu                   = 512
      memory               = 1024
      desired_count        = 2
      min_capacity         = 2
      max_capacity         = 15
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]
    }
    "order-service" = {
      cpu                   = 512
      memory               = 1024
      desired_count        = 2
      min_capacity         = 2
      max_capacity         = 20
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]
    }
    "payment-service" = {
      cpu                   = 512
      memory               = 1024
      desired_count        = 3
      min_capacity         = 3
      max_capacity         = 30
      cpu_target_value     = 60
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]
    }
    "qr-service" = {
      cpu                   = 256
      memory               = 512
      desired_count        = 2
      min_capacity         = 2
      max_capacity         = 15
      cpu_target_value     = 70
      memory_target_value  = 80
      environment_variables = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod"
        }
      ]
    }
  }
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}