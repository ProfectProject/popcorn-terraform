output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = aws_security_group.ecs.id
}

output "aurora_security_group_id" {
  description = "ID of the Aurora security group"
  value       = aws_security_group.aurora.id
}

output "elasticache_security_group_id" {
  description = "ID of the ElastiCache security group"
  value       = aws_security_group.elasticache.id
}

output "msk_security_group_id" {
  description = "ID of the MSK security group"
  value       = aws_security_group.msk.id
}

output "kafka_security_group_id" {
  description = "ID of the Kafka security group"
  value       = aws_security_group.kafka.id
}