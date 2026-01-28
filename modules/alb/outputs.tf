output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch metrics"
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.gateway.arn
}

output "payment_front_target_group_arn" {
  description = "Payment front target group ARN"
  value       = aws_lb_target_group.payment_front.arn
}

output "listener_arn" {
  value = aws_lb_listener.https.arn
}
