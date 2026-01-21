variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "app_subnets" {
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "data_subnets" {
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "sg_name" {
  type = string
}

variable "enable_nat" {
  type    = bool
  default = false
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "alb_name" {
  type = string
}

variable "alb_target_group_name" {
  type = string
}

variable "alb_target_group_port" {
  type    = number
  default = 8080
}

variable "alb_health_check_path" {
  type    = string
  default = "/health"
}

variable "elasticache_name" {
  type = string
}

variable "elasticache_node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "elasticache_engine_version" {
  type    = string
  default = "7.0"
}

variable "elasticache_num_cache_clusters" {
  type    = number
  default = 2
}

variable "elasticache_automatic_failover" {
  type    = bool
  default = true
}

variable "elasticache_multi_az_enabled" {
  type    = bool
  default = true
}
