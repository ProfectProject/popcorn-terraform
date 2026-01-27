provider "aws" {
  region = var.region
}

# Global Route53 & ACM 상태 참조
data "terraform_remote_state" "global_route53_acm" {
  backend = "s3"

  config = {
    bucket = "goorm-popcorn-tfstate"
    key    = "global/route53-acm/terraform.tfstate"
    region = var.region
  }
}

# Global ECR 상태 참조
data "terraform_remote_state" "global_ecr" {
  backend = "s3"

  config = {
    bucket = "goorm-popcorn-tfstate"
    key    = "global/ecr/terraform.tfstate"
    region = var.region
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.vpc_name
  cidr               = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  data_subnets       = var.data_subnets
  enable_nat         = var.enable_nat
  single_nat_gateway = var.single_nat_gateway
}

module "security_groups" {
  source = "../../modules/security-groups"

  name   = var.sg_name
  vpc_id = module.vpc.vpc_id
}

# ALB 모듈 - Route53 트래픽 수신용 (Multi-AZ Public 서브넷)
module "alb" {
  source = "../../modules/alb"

  name              = var.alb_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = values(module.vpc.public_subnet_ids)
  security_group_id = module.security_groups.alb_sg_id
  certificate_arn   = data.terraform_remote_state.global_route53_acm.outputs.certificate_arn
  target_group_name = var.alb_target_group_name
  target_group_port = var.alb_target_group_port
  health_check_path = var.alb_health_check_path
}

# Route53 레코드 - 외부 트래픽 수신
resource "aws_route53_record" "dev" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "dev.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

module "elasticache" {
  source = "../../modules/elasticache"

  name                       = var.elasticache_name
  subnet_ids                 = values(module.vpc.data_subnet_ids)
  security_group_id          = module.security_groups.cache_sg_id
  node_type                  = var.elasticache_node_type
  engine_version             = var.elasticache_engine_version
  num_cache_clusters         = var.elasticache_num_cache_clusters
  automatic_failover_enabled = var.elasticache_automatic_failover
  multi_az_enabled           = var.elasticache_multi_az_enabled

  # Dev 환경 최적화 설정
  transit_encryption_enabled = false # 개발 환경에서는 성능 우선
  apply_immediately          = true  # 즉시 적용
  snapshot_retention_limit   = 1     # 최소 백업 보존
  snapshot_window            = "03:00-05:00"
  maintenance_window         = "sun:05:00-sun:07:00"

  tags = var.tags
}

# IAM 역할 모듈
module "iam" {
  source = "../../modules/iam"

  name        = var.iam_name
  environment = "dev"
  region      = var.region

  tags = var.tags
}

# RDS PostgreSQL 모듈 (Dev 환경용) - 단일 인스턴스, Multi-AZ 비활성화
module "rds" {
  source = "../../modules/rds"

  name              = var.rds_name
  environment       = "dev"
  subnet_ids        = values(module.vpc.data_subnet_ids)
  security_group_id = module.security_groups.db_sg_id

  # PostgreSQL 설정
  engine_version = var.rds_engine_version

  # Dev 환경 최적화 설정
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  backup_retention_period = var.rds_backup_retention_period
  multi_az                = false # 단일 인스턴스 (비용 절약)
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = var.tags
}

# CloudMap 서비스 디스커버리 모듈
module "cloudmap" {
  source = "../../modules/cloudmap"

  name           = var.cloudmap_name
  vpc_id         = module.vpc.vpc_id
  namespace_name = var.cloudmap_namespace
  dns_ttl        = var.cloudmap_dns_ttl

  tags = var.tags
}

# EC2 Kafka 모듈
module "ec2_kafka" {
  source = "../../modules/ec2-kafka"

  name              = var.ec2_kafka_name
  environment       = "dev"
  node_count        = var.ec2_kafka_node_count
  instance_type     = var.ec2_kafka_instance_type
  key_name          = var.ec2_kafka_key_name
  subnet_ids        = values(module.vpc.private_subnet_ids)
  security_group_id = module.security_groups.kafka_sg_id

  # IAM instance profile
  iam_instance_profile = module.iam.ec2_ssm_instance_profile_name

  # Dev 환경 설정
  root_volume_size = 8
  data_volume_size = 20

  tags = var.tags
}

# ECS Fargate 모듈
module "ecs" {
  source = "../../modules/ecs"

  name        = var.ecs_name
  environment = "dev"
  region      = var.region
  vpc_id      = module.vpc.vpc_id

  # 네트워크 설정
  subnet_ids        = values(module.vpc.private_subnet_ids)
  security_group_id = module.security_groups.ecs_sg_id

  # IAM 역할
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn

  # ALB 연결 - Route53 트래픽 수신용
  alb_target_group_arn = module.alb.target_group_arn
  alb_listener_arn     = module.alb.listener_arn

  # ECR 설정 (Global ECR 리포지토리 사용)
  ecr_repository_url = try(data.terraform_remote_state.global_ecr.outputs.repository_url, var.ecr_repository_url)
  ecr_repositories   = var.ecr_repositories
  image_tag          = var.image_tag

  # 서비스 디스커버리
  service_discovery_service_arns = module.cloudmap.service_arns

  # 외부 서비스 연결
  elasticache_primary_endpoint = module.elasticache.primary_endpoint
  elasticache_reader_endpoint  = module.elasticache.reader_endpoint
  database_endpoint            = module.rds.endpoint
  database_port                = module.rds.port
  database_name                = module.rds.database_name
  database_secret_arn          = module.rds.master_password_secret_arn
  kafka_bootstrap_servers      = module.ec2_kafka.bootstrap_servers

  # 로그 설정
  log_retention_days = var.ecs_log_retention_days

  tags = var.tags

  depends_on = [
    module.iam,
    module.rds,
    module.cloudmap,
    module.ec2_kafka
  ]
}
