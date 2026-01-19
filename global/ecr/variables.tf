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

variable "service_names" {
  description = "List of service names for ECR repositories"
  type        = list(string)
  default = [
    "api-gateway",
    "user-service",
    "store-service",
    "order-service",
    "payment-service",
    "qr-service"
  ]
}