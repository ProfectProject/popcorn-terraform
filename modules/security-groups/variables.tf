# Security Groups 모듈 변수 정의

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "environment" {
  description = "환경 (dev/prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment는 'dev' 또는 'prod'여야 합니다."
  }
}

variable "whitelist_ips" {
  description = "Management ALB 화이트리스트 IP 목록 (CIDR 형식)"
  type        = list(string)
  default     = []
}

variable "eks_node_security_group_id" {
  description = "EKS 노드 보안 그룹 ID (EKS 모듈에서 생성)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}
