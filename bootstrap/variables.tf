variable "bucket_name" {
  description = "S3 백엔드 버킷 이름"
  type        = string
}

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}
