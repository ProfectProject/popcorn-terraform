# EC2 Kafka Module Variables

variable "name" {
  description = "Base name for Kafka resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "node_count" {
  description = "Number of Kafka nodes"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type for Kafka nodes"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where Kafka nodes will be deployed"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for Kafka instances"
  type        = string
}

variable "private_ips" {
  description = "List of private IP addresses for Kafka nodes (optional)"
  type        = list(string)
  default     = []
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 8
}

variable "data_volume_size" {
  description = "Size of the data EBS volume in GB"
  type        = number
  default     = 20
}

variable "data_volume_iops" {
  description = "IOPS for the data EBS volume"
  type        = number
  default     = 3000
}

variable "data_volume_throughput" {
  description = "Throughput for the data EBS volume in MB/s"
  type        = number
  default     = 125
}

variable "iam_instance_profile" {
  description = "IAM instance profile for Kafka instances"
  type        = string
  default     = null
}

variable "create_dns_records" {
  description = "Whether to create Route53 DNS records"
  type        = bool
  default     = false
}

variable "private_zone_id" {
  description = "Route53 private hosted zone ID"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}