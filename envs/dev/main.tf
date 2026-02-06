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

  # 모니터링 설정 (기본값으로 CloudWatch 알람 활성화)
  enable_cloudwatch_alarms = true
  enable_access_logs       = false # S3 비용 절약을 위해 비활성화

  tags = var.tags
}

# Route53 레코드 - 메인 도메인 및 서브도메인
resource "aws_route53_record" "main" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "api.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "kafka" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "kafka.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "argocd" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "argocd.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "grafana.goormpopcorn.shop"
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

  # 모니터링 설정 (기본값으로 CloudWatch 알람 활성화)
  enable_cloudwatch_alarms = true

  tags = var.tags
}

# IAM 역할 모듈
module "iam" {
  source = "../../modules/iam"

  name        = var.iam_name
  environment = "dev"
  region      = var.region

  # EKS 관련 IAM 역할 추가
  enable_eks_roles = true

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

# EKS 클러스터 모듈
module "eks" {
  source = "../../modules/eks"

  name        = var.eks_name
  environment = "dev"
  region      = var.region
  vpc_id      = module.vpc.vpc_id

  # 네트워크 설정
  subnet_ids         = values(module.vpc.private_subnet_ids)
  control_plane_subnet_ids = values(module.vpc.public_subnet_ids)
  
  # 노드 그룹 설정
  node_group_instance_types = var.eks_node_instance_types
  node_group_capacity_type  = var.eks_node_capacity_type
  node_group_min_size       = var.eks_node_min_size
  node_group_max_size       = var.eks_node_max_size
  node_group_desired_size   = var.eks_node_desired_size

  # Kubernetes 버전
  cluster_version = var.eks_cluster_version

  # Add-ons 설정
  enable_aws_load_balancer_controller = true
  enable_karpenter                    = true
  enable_ebs_csi_driver              = true

  tags = var.tags
}

# EKS 클러스터 모듈
module "eks" {
  source = "../../modules/eks"

  name        = var.eks_name
  environment = "dev"
  region      = var.region
  vpc_id      = module.vpc.vpc_id

  # 네트워크 설정
  subnet_ids         = values(module.vpc.private_subnet_ids)
  control_plane_subnet_ids = values(module.vpc.public_subnet_ids)
  
  # 노드 그룹 설정
  node_group_instance_types = var.eks_node_instance_types
  node_group_capacity_type  = var.eks_node_capacity_type
  node_group_min_size       = var.eks_node_min_size
  node_group_max_size       = var.eks_node_max_size
  node_group_desired_size   = var.eks_node_desired_size

  # Kubernetes 버전
  cluster_version = var.eks_cluster_version

  # Add-ons 설정
  enable_aws_load_balancer_controller = true
  enable_karpenter                    = true
  enable_ebs_csi_driver              = true

  tags = var.tags
}

# 통합 모니터링 모듈 (SNS 없이)
module "monitoring" {
  source = "../../modules/monitoring"

  name   = var.eks_name
  region = var.region

  # 기존 리소스 연결
  alb_arn_suffix         = module.alb.alb_arn_suffix
  rds_instance_id        = module.rds.instance_id
  elasticache_cluster_id = module.elasticache.cluster_id

  # SNS 알림 비활성화 (기본값)
  enable_sns_alerts = false

  tags = var.tags

  depends_on = [
    module.alb,
    module.rds,
    module.elasticache
  ]
}
