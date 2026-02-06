# IAM Module Variables

variable "name" {
  description = "Base name for IAM resources"
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

variable "enable_eks_roles" {
  description = "Enable EKS-related IAM roles"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}