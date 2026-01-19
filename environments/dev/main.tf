terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  backend "s3" {
    bucket         = "goorm-popcorn-terraform-state-dev"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC Module - 단일 AZ로 비용 절감
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  region             = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = [local.azs[0]]  # 단일 AZ만 사용

  public_subnet_cidrs      = [var.public_subnet_cidrs[0]]      # 1개만
  private_app_subnet_cidrs = [var.private_app_subnet_cidrs[0]] # 1개만
  private_data_subnet_cidrs = [var.private_data_subnet_cidrs[0]] # 1개만

  enable_nat_gateway    = var.enable_nat_gateway
  enable_vpc_endpoints  = var.enable_vpc_endpoints

  tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  region       = var.aws_region
  account_id   = local.account_id

  tags = local.common_tags
}

# ALB Module
module "alb" {
  source = "../../modules/alb"

  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  alb_security_group_id     = module.security_groups.alb_security_group_id
  certificate_arn           = var.certificate_arn
  enable_deletion_protection = false

  tags = local.common_tags
}

# CloudMap Module
module "cloudmap" {
  source = "../../modules/cloudmap"

  project_name   = var.project_name
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  namespace_name = "${var.project_name}-dev.local"

  tags = local.common_tags
}

# RDS Module - 최소 구성
module "rds" {
  source = "../../modules/rds"

  project_name              = var.project_name
  environment               = var.environment
  private_data_subnet_ids   = module.vpc.private_data_subnet_ids
  aurora_security_group_id  = module.security_groups.aurora_security_group_id

  engine_version            = var.aurora_engine_version
  instance_class            = var.aurora_instance_class  # db.t4g.medium (소형)
  instance_count            = var.aurora_instance_count  # 1개만
  database_name             = var.database_name
  master_username           = var.master_username

  backup_retention_period   = 1  # 최소 백업
  performance_insights_enabled = false  # 비활성화
  monitoring_interval       = 0  # 모니터링 비활성화

  enable_autoscaling        = false  # Auto Scaling 비활성화
  autoscaling_min_capacity  = 1
  autoscaling_max_capacity  = 1
  autoscaling_target_cpu    = 80

  tags = local.common_tags
}

# ElastiCache Module - 최소 구성
module "elasticache" {
  source = "../../modules/elasticache"

  project_name                  = var.project_name
  environment                   = var.environment
  private_data_subnet_ids       = module.vpc.private_data_subnet_ids
  elasticache_security_group_id = module.security_groups.elasticache_security_group_id

  node_type                    = var.elasticache_node_type  # cache.t4g.micro
  engine_version               = var.elasticache_engine_version
  num_cache_clusters           = 1  # 단일 노드
  multi_az_enabled             = false  # Multi-AZ 비활성화
  automatic_failover_enabled   = false  # 자동 장애조치 비활성화

  snapshot_retention_limit     = 1  # 최소 스냅샷

  tags = local.common_tags
}

# MSK Module - 개발용으로는 SQS/SNS 대체 고려하지만 일단 MSK Serverless 유지
module "msk" {
  source = "../../modules/msk"

  project_name            = var.project_name
  environment             = var.environment
  private_app_subnet_ids  = module.vpc.private_app_subnet_ids
  msk_security_group_id   = module.security_groups.msk_security_group_id

  enable_monitoring       = false  # 모니터링 비활성화

  tags = local.common_tags
}

# ECS Module - 최소 구성
module "ecs" {
  source = "../../modules/ecs"

  project_name                    = var.project_name
  environment                     = var.environment
  region                          = var.aws_region
  account_id                      = local.account_id
  vpc_id                          = module.vpc.vpc_id
  private_app_subnet_ids          = module.vpc.private_app_subnet_ids
  ecs_security_group_id           = module.security_groups.ecs_security_group_id
  ecs_task_execution_role_arn     = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn               = module.iam.ecs_task_role_arn
  alb_target_group_arn            = module.alb.api_gateway_target_group_arn
  alb_listener_arn                = module.alb.https_listener_arn
  ecr_repository_url              = var.ecr_repository_url
  service_discovery_service_arns  = module.cloudmap.service_arns

  log_retention_days              = 3  # 짧은 로그 보존

  services = var.ecs_services  # 개발용 소규모 설정

  tags = local.common_tags
}