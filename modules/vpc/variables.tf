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

variable "app_subnets" {
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

variable "tags" {
  type    = map(string)
  default = {}
}
