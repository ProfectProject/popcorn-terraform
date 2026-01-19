output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.alb.alb_dns_name
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.rds.cluster_endpoint
}

output "elasticache_primary_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = module.elasticache.primary_endpoint_address
}

output "msk_bootstrap_brokers" {
  description = "MSK bootstrap brokers"
  value       = module.msk.bootstrap_brokers_sasl_iam
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = module.cloudmap.namespace_name
}

# 개발환경 접속 정보
output "dev_access_info" {
  description = "Development environment access information"
  value = {
    api_endpoint = "https://${module.alb.alb_dns_name}"
    database_endpoint = module.rds.cluster_endpoint
    redis_endpoint = module.elasticache.primary_endpoint_address
    environment = "dev"
    cost_optimization = "Single AZ, minimal instances, no auto-scaling"
  }
}