# Dev Environment Outputs

# VPC 정보
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

# 서브넷 정보
output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "app_subnet_ids" {
  description = "App subnet IDs"
  value       = module.vpc.app_subnet_ids
}

output "data_subnet_ids" {
  description = "Data subnet IDs"
  value       = module.vpc.data_subnet_ids
}

# ALB 정보
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID"
  value       = module.alb.zone_id
}

# RDS 정보
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.database_name
}

output "rds_secret_arn" {
  description = "RDS master password secret ARN"
  value       = module.rds.master_password_secret_arn
  sensitive   = true
}

# ElastiCache 정보
output "elasticache_primary_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = module.elasticache.primary_endpoint
}

output "elasticache_reader_endpoint" {
  description = "ElastiCache reader endpoint"
  value       = module.elasticache.reader_endpoint
}

# Kafka 정보
output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap servers"
  value       = module.ec2_kafka.bootstrap_servers
}

output "kafka_cluster_id" {
  description = "Kafka cluster ID"
  value       = module.ec2_kafka.cluster_id
}

output "kafka_instance_ids" {
  description = "Kafka instance IDs"
  value       = module.ec2_kafka.instance_ids
}

output "kafka_private_ips" {
  description = "Kafka private IPs"
  value       = module.ec2_kafka.private_ips
}

# ECS 정보
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "ecs_service_arns" {
  description = "ECS service ARNs"
  value       = module.ecs.service_arns
}

# CloudMap 정보
output "cloudmap_namespace_id" {
  description = "CloudMap namespace ID"
  value       = module.cloudmap.namespace_id
}

output "cloudmap_namespace_name" {
  description = "CloudMap namespace name"
  value       = module.cloudmap.namespace_name
}

output "cloudmap_service_arns" {
  description = "CloudMap service ARNs"
  value       = module.cloudmap.service_arns
}

# IAM 정보
output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = module.iam.ecs_task_role_arn
}