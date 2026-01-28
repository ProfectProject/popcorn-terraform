variable "name" {
  type = string
}

variable "cidr" {
  type = string
}

variable "public_subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
  }))
}

variable "data_subnets" {
  type = list(object({
    name = string
    cidr = string
    az   = string
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

variable "tags" {
  type    = map(string)
  default = {}
}
# VPC Flow Logs 관련 변수
variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log retention days for VPC Flow Logs"
  type        = number
  default     = 7
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = null
}