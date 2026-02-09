# Security Groups 모듈 출력 값

output "public_alb_sg_id" {
  description = "Public ALB 보안 그룹 ID"
  value       = aws_security_group.public_alb.id
}

output "management_alb_sg_id" {
  description = "Management ALB 보안 그룹 ID"
  value       = aws_security_group.management_alb.id
}

output "rds_sg_id" {
  description = "RDS 보안 그룹 ID"
  value       = aws_security_group.rds.id
}

output "elasticache_sg_id" {
  description = "ElastiCache 보안 그룹 ID"
  value       = aws_security_group.elasticache.id
}

# 추가 출력 값 (디버깅 및 참조용)

output "public_alb_sg_name" {
  description = "Public ALB 보안 그룹 이름"
  value       = aws_security_group.public_alb.name
}

output "management_alb_sg_name" {
  description = "Management ALB 보안 그룹 이름"
  value       = aws_security_group.management_alb.name
}

output "rds_sg_name" {
  description = "RDS 보안 그룹 이름"
  value       = aws_security_group.rds.name
}

output "elasticache_sg_name" {
  description = "ElastiCache 보안 그룹 이름"
  value       = aws_security_group.elasticache.name
}
