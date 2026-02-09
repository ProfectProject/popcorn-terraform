# Production Environment Outputs

# VPC 정보
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.vpc_cidr
}

# 서브넷 정보
output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  description = "Data subnet IDs"
  value       = module.vpc.data_subnet_ids
}

# Public ALB 정보 (Frontend 서비스용)
output "public_alb_dns_name" {
  description = "Public ALB DNS name"
  value       = module.public_alb.alb_dns_name
}

output "public_alb_zone_id" {
  description = "Public ALB zone ID"
  value       = module.public_alb.alb_zone_id
}

output "public_alb_arn" {
  description = "Public ALB ARN"
  value       = module.public_alb.alb_arn
}

# Management ALB 정보 (관리 도구용)
output "management_alb_dns_name" {
  description = "Management ALB DNS name"
  value       = module.management_alb.alb_dns_name
}

output "management_alb_zone_id" {
  description = "Management ALB zone ID"
  value       = module.management_alb.alb_zone_id
}

output "management_alb_arn" {
  description = "Management ALB ARN"
  value       = module.management_alb.alb_arn
}

# EKS 클러스터 정보
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "eks_cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "eks_node_security_group_id" {
  description = "EKS node security group ID"
  value       = module.eks.node_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

# RDS 정보
output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_address" {
  description = "RDS address (hostname)"
  value       = module.rds.db_instance_address
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_instance_name
}

output "rds_instance_id" {
  description = "RDS instance ID"
  value       = module.rds.db_instance_id
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = module.rds.db_instance_arn
}

output "rds_secret_arn" {
  description = "RDS master password secret ARN"
  value       = aws_secretsmanager_secret.db_password.arn
  sensitive   = true
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

output "rds_jdbc_url" {
  description = "RDS JDBC connection URL"
  value       = module.rds.db_jdbc_url
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

output "elasticache_cluster_id" {
  description = "ElastiCache cluster ID"
  value       = module.elasticache.cluster_id
}

output "elasticache_port" {
  description = "ElastiCache port"
  value       = module.elasticache.port
}

# IAM 정보
output "ecs_task_execution_role_arn" {
  description = "ECS task execution IAM role ARN"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS task IAM role ARN"
  value       = module.iam.ecs_task_role_arn
}

output "ec2_ssm_role_arn" {
  description = "EC2 SSM IAM role ARN"
  value       = module.iam.ec2_ssm_role_arn
}

output "ec2_ssm_instance_profile_name" {
  description = "EC2 SSM instance profile name"
  value       = module.iam.ec2_ssm_instance_profile_name
}

# Route53 정보
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.terraform_remote_state.global_route53_acm.outputs.zone_id
}

output "route53_domain_name" {
  description = "Route53 domain name"
  value       = "goormpopcorn.shop"
}

output "route53_api_domain" {
  description = "Route53 API domain"
  value       = "api.goormpopcorn.shop"
}

output "route53_kafka_domain" {
  description = "Route53 Kafka domain"
  value       = "kafka.goormpopcorn.shop"
}

output "route53_argocd_domain" {
  description = "Route53 ArgoCD domain"
  value       = "argocd.goormpopcorn.shop"
}

output "route53_grafana_domain" {
  description = "Route53 Grafana domain"
  value       = "grafana.goormpopcorn.shop"
}

# 보안 그룹 정보
output "public_alb_security_group_id" {
  description = "Public ALB security group ID"
  value       = module.security_groups.public_alb_sg_id
}

output "management_alb_security_group_id" {
  description = "Management ALB security group ID"
  value       = module.security_groups.management_alb_sg_id
}

output "elasticache_security_group_id" {
  description = "ElastiCache security group ID"
  value       = module.security_groups.elasticache_sg_id
}

# 모니터링 정보
output "sns_topic_arn" {
  description = "SNS topic ARN for monitoring alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

output "rds_sns_topic_arn" {
  description = "RDS SNS topic ARN for alerts"
  value       = aws_sns_topic.rds_alerts.arn
}
