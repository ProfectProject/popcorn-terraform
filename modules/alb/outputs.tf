output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix (CloudWatch 메트릭용)"
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "ALB DNS 이름"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB Zone ID (Route53 레코드용)"
  value       = aws_lb.this.zone_id
}

output "default_target_group_arn" {
  description = "기본 타겟 그룹 ARN"
  value       = aws_lb_target_group.default.arn
}

output "target_group_arns" {
  description = "모든 타겟 그룹 ARN 목록 (기본 + 추가)"
  value       = concat([aws_lb_target_group.default.arn], aws_lb_target_group.additional[*].arn)
}

output "listener_arn" {
  description = "HTTPS 리스너 ARN"
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "HTTP 리스너 ARN (리다이렉트용)"
  value       = aws_lb_listener.http.arn
}
