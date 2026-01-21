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
