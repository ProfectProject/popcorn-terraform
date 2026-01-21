variable "name" {
  type = string
}

variable "public_subnets" {
  type = list(object({
    name = string
    az   = string
    cidr = string
  }))
}

variable "nat_azs" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
