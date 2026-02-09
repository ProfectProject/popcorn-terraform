# VPC 출력
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public 서브넷 ID 목록"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private App 서브넷 ID 목록"
  value       = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Private Data 서브넷 ID 목록"
  value       = module.vpc.data_subnet_ids
}

# ALB 출력
output "public_alb_dns_name" {
  description = "Public ALB DNS 이름"
  value       = module.public_alb.alb_dns_name
}

output "public_alb_zone_id" {
  description = "Public ALB Zone ID"
  value       = module.public_alb.alb_zone_id
}

output "management_alb_dns_name" {
  description = "Management ALB DNS 이름"
  value       = module.management_alb.alb_dns_name
}

output "management_alb_zone_id" {
  description = "Management ALB Zone ID"
  value       = module.management_alb.alb_zone_id
}

# RDS 출력
output "rds_endpoint" {
  description = "RDS 엔드포인트"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS 포트"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS 데이터베이스 이름"
  value       = module.rds.db_instance_name
}

output "rds_secret_arn" {
  description = "RDS 마스터 비밀번호 Secret ARN"
  value       = module.rds.secrets_manager_secret_arn
  sensitive   = true
}

# ElastiCache 출력
output "elasticache_endpoint" {
  description = "ElastiCache 엔드포인트"
  value       = module.elasticache.primary_endpoint
  sensitive   = true
}

output "elasticache_port" {
  description = "ElastiCache 포트"
  value       = module.elasticache.port
}

# EKS 출력
output "eks_cluster_id" {
  description = "EKS 클러스터 ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "eks_cluster_version" {
  description = "EKS 클러스터 Kubernetes 버전"
  value       = module.eks.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC Provider ARN"
  value       = module.eks.oidc_provider_arn
}

# Security Groups 출력
output "public_alb_sg_id" {
  description = "Public ALB 보안 그룹 ID"
  value       = module.security_groups.public_alb_sg_id
}

output "management_alb_sg_id" {
  description = "Management ALB 보안 그룹 ID"
  value       = module.security_groups.management_alb_sg_id
}

output "rds_sg_id" {
  description = "RDS 보안 그룹 ID"
  value       = module.security_groups.rds_sg_id
}

output "elasticache_sg_id" {
  description = "ElastiCache 보안 그룹 ID"
  value       = module.security_groups.elasticache_sg_id
}

# Route53 출력
output "route53_records" {
  description = "Route53 레코드 목록"
  value = {
    main    = "dev.goormpopcorn.shop"
    api     = "api-dev.goormpopcorn.shop"
    kafka   = "kafka-dev.goormpopcorn.shop"
    argocd  = "argocd-dev.goormpopcorn.shop"
    grafana = "grafana-dev.goormpopcorn.shop"
  }
}
