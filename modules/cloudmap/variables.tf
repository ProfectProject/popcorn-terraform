# CloudMap Service Discovery Module Variables

variable "name" {
  description = "Base name for CloudMap resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the private DNS namespace"
  type        = string
}

variable "namespace_name" {
  description = "Name of the private DNS namespace"
  type        = string
  default     = "goormpopcorn.local"
}

variable "service_names" {
  description = "List of service names to register"
  type        = list(string)
  default     = ["api-gateway", "user-service", "store-service", "order-service", "payment-service", "checkin-service", "order-query"]
}

variable "health_check_grace_period" {
  description = "Health check grace period in seconds"
  type        = number
  default     = 30
}

variable "dns_ttl" {
  description = "DNS TTL in seconds"
  type        = number
  default     = 60
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}