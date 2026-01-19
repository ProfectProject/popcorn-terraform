# 인프라 정보
output "infrastructure_info" {
  description = "Infrastructure information"
  value = {
    vpc_id      = module.vpc.vpc_id
    vpc_cidr    = module.vpc.vpc_cidr_block
    region      = var.aws_region
    environment = var.environment
  }
}

# 네트워크 정보
output "network_info" {
  description = "Network configuration"
  value = {
    public_subnets       = module.vpc.public_subnet_ids
    private_app_subnets  = module.vpc.private_app_subnet_ids
    private_data_subnets = module.vpc.private_data_subnet_ids
    security_groups = {
      alb         = module.vpc.alb_security_group_id
      ecs         = module.vpc.ecs_security_group_id
      rds         = module.vpc.rds_security_group_id
      elasticache = module.vpc.elasticache_security_group_id
    }
  }
}

# 애플리케이션 엔드포인트
output "application_endpoints" {
  description = "Application endpoints"
  value = {
    api_url           = "https://${module.alb.alb_dns_name}"
    alb_dns           = module.alb.alb_dns_name
    database_endpoint = module.rds.cluster_endpoint
    cache_endpoint    = module.elasticache.primary_endpoint_address
  }
}

# 배포 정보
output "deployment_info" {
  description = "Deployment information"
  value = {
    ecs_cluster_name            = module.ecs.cluster_name
    task_execution_role_arn     = module.ecs.task_execution_role_arn
    task_role_arn              = module.ecs.task_role_arn
    target_group_arns          = module.alb.target_group_arns
    service_discovery_namespace = module.cloudmap.namespace_name
  }
}

# 프로덕션 환경 정보
output "production_info" {
  description = "Production environment information"
  value = {
    api_endpoint        = "https://${module.alb.alb_dns_name}"
    database_endpoint   = module.rds.cluster_endpoint
    redis_endpoint      = module.elasticache.primary_endpoint_address
    environment         = "prod"
    high_availability   = "Multi-AZ, auto-scaling enabled"
    backup_retention    = "7 days"
    monitoring_enabled  = true
  }
}

# 고가용성 정보
output "high_availability_info" {
  description = "High availability configuration"
  value = {
    availability_zones    = var.availability_zones
    multi_az_rds         = true
    auto_scaling_enabled = true
    backup_enabled       = true
    monitoring_enabled   = true
    vpc_endpoints        = true
  }
}

# 민감한 정보
output "sensitive_info" {
  description = "Sensitive configuration"
  value = {
    database_master_username = module.rds.cluster_master_username
    msk_bootstrap_brokers    = try(module.msk.bootstrap_brokers_sasl_iam, "N/A")
  }
  sensitive = true
}