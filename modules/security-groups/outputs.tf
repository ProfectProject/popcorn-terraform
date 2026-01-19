output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}

output "cache_sg_id" {
  value = aws_security_group.cache.id
}

output "kafka_sg_id" {
  value = aws_security_group.kafka.id
}
