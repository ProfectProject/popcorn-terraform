variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "cache_port" {
  type    = number
  default = 6379
}

variable "kafka_ports" {
  type    = list(number)
  default = [9092, 9094]
}

variable "tags" {
  type    = map(string)
  default = {}
}
