variable "name" {
  description = "Name prefix for X-Ray resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "KMS key ID for X-Ray encryption"
  type        = string
  default     = null
}

variable "log_group_names" {
  description = "CloudWatch log group names for X-Ray analysis"
  type        = list(string)
  default     = []
}