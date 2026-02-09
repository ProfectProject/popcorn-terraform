variable "name" {
  description = "ALB 이름"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "ALB를 배치할 서브넷 ID 목록 (Public Subnet)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "ALB에 연결할 보안 그룹 ID 목록"
  type        = list(string)
}

variable "internal" {
  description = "내부 ALB 여부 (true: 내부, false: 외부)"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM 인증서 ARN (HTTPS 리스너용)"
  type        = string
}

variable "target_group_name" {
  description = "기본 타겟 그룹 이름"
  type        = string
  default     = null
}

variable "target_group_port" {
  description = "기본 타겟 그룹 포트"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "기본 헬스체크 경로"
  type        = string
  default     = "/actuator/health"
}

# 다중 타겟 그룹 및 리스너 규칙 설정
variable "target_groups" {
  description = "타겟 그룹 설정 목록 (Host-based 라우팅용)"
  type = list(object({
    name     = string
    port     = number
    protocol = string
    health_check = object({
      path                = string
      interval            = number
      timeout             = number
      healthy_threshold   = number
      unhealthy_threshold = number
      matcher             = string
    })
  }))
  default = []
}

variable "listener_rules" {
  description = "리스너 규칙 설정 목록 (Host-based 라우팅)"
  type = list(object({
    priority           = number
    host_header        = string
    target_group_index = number
  }))
  default = []
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type        = map(string)
  default     = {}
}

# CloudWatch 모니터링 관련 변수
variable "enable_access_logs" {
  description = "ALB 액세스 로그 활성화 여부"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "ALB 액세스 로그를 저장할 S3 버킷"
  type        = string
  default     = null
}

variable "access_logs_prefix" {
  description = "ALB 액세스 로그 S3 prefix"
  type        = string
  default     = "alb"
}

variable "enable_cloudwatch_alarms" {
  description = "CloudWatch 알람 활성화 여부"
  type        = bool
  default     = true
}

variable "sns_topic_arn" {
  description = "CloudWatch 알람용 SNS 토픽 ARN (선택적)"
  type        = string
  default     = null
}
