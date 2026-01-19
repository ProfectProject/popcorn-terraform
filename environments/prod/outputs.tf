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

output "aurora_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = module.rds.cluster_reader_endpoint
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