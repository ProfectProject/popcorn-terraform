variable "name" {
  type = string
}

variable "replication_group_id" {
  type    = string
  default = ""
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "node_type" {
  type = string
}

variable "engine_version" {
  type    = string
  default = "7.0"
}

variable "num_cache_clusters" {
  type    = number
  default = 1
}

variable "port" {
  type    = number
  default = 6379
}

variable "automatic_failover_enabled" {
  type    = bool
  default = false
}

variable "multi_az_enabled" {
  type    = bool
  default = false
}

variable "at_rest_encryption_enabled" {
  type    = bool
  default = true
}

variable "transit_encryption_enabled" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
