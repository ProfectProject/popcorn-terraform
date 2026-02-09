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

# VPC 모듈 - 단일 AZ 구성 (비용 절감)
module "vpc" {
  source = "../../modules/vpc"

  name               = var.vpc_name
  cidr               = var.vpc_cidr
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  data_subnets       = var.data_subnets
  enable_nat         = var.enable_nat
  single_nat_gateway = var.single_nat_gateway # Dev: true (비용 절감)
}

# Security Groups 모듈
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id        = module.vpc.vpc_id
  environment   = "dev"
  whitelist_ips = var.whitelist_ips
  tags          = var.tags
}

# Public ALB 모듈 - Frontend 서비스용 (0.0.0.0/0 허용)
module "public_alb" {
  source = "../../modules/alb"

  name               = var.public_alb_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = values(module.vpc.public_subnet_ids)
  security_group_ids = [module.security_groups.public_alb_sg_id]
  internal           = false
  certificate_arn    = data.terraform_remote_state.global_route53_acm.outputs.certificate_arn
  target_group_name  = var.public_alb_target_group_name
  target_group_port  = var.public_alb_target_group_port
  health_check_path  = var.public_alb_health_check_path

  # 모니터링 설정
  enable_cloudwatch_alarms = true
  enable_access_logs       = false # Dev 환경에서는 비용 절감을 위해 비활성화

  tags = var.tags
}

# Management ALB 모듈 - Kafka, ArgoCD, Grafana용 (IP 화이트리스트만 허용)
module "management_alb" {
  source = "../../modules/alb"

  name               = var.management_alb_name
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = values(module.vpc.public_subnet_ids)
  security_group_ids = [module.security_groups.management_alb_sg_id]
  internal           = false
  certificate_arn    = data.terraform_remote_state.global_route53_acm.outputs.certificate_arn
  target_group_name  = var.management_alb_target_group_name
  target_group_port  = var.management_alb_target_group_port
  health_check_path  = var.management_alb_health_check_path

  # 모니터링 설정
  enable_cloudwatch_alarms = true
  enable_access_logs       = false # Dev 환경에서는 비용 절감을 위해 비활성화

  tags = var.tags
}

# Route53 레코드 - Public ALB (Frontend 서비스)
resource "aws_route53_record" "main" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "dev.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.public_alb.alb_dns_name
    zone_id                = module.public_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "api-dev.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.public_alb.alb_dns_name
    zone_id                = module.public_alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Route53 레코드 - Management ALB (관리 도구)
resource "aws_route53_record" "kafka" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "kafka-dev.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "argocd" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "argocd-dev.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "grafana-dev.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Route53 헬스체크 - Management ALB 서브도메인
resource "aws_route53_health_check" "kafka" {
  fqdn              = "kafka-dev.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "kafka-dev-goormpopcorn-shop-health-check"
  })
}

resource "aws_route53_health_check" "argocd" {
  fqdn              = "argocd-dev.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "argocd-dev-goormpopcorn-shop-health-check"
  })
}

resource "aws_route53_health_check" "grafana" {
  fqdn              = "grafana-dev.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "grafana-dev-goormpopcorn-shop-health-check"
  })
}

# ElastiCache 모듈 - 단일 노드 (비용 절감)
module "elasticache" {
  source = "../../modules/elasticache"

  name                       = var.elasticache_name
  subnet_ids                 = values(module.vpc.data_subnet_ids)
  security_group_id          = module.security_groups.elasticache_sg_id
  node_type                  = var.elasticache_node_type
  engine_version             = var.elasticache_engine_version
  num_cache_clusters         = var.elasticache_num_cache_clusters # Dev: 1 (단일 노드)
  automatic_failover_enabled = var.elasticache_automatic_failover # Dev: false
  multi_az_enabled           = var.elasticache_multi_az_enabled   # Dev: false

  # Dev 환경 설정 (비용 절감)
  transit_encryption_enabled = false # Dev에서는 비활성화
  apply_immediately          = true  # Dev에서는 즉시 적용
  snapshot_retention_limit   = 1     # 1일 백업 보존
  snapshot_window            = "02:00-04:00"
  maintenance_window         = "sun:04:00-sun:06:00"

  # 모니터링 설정
  enable_cloudwatch_alarms = true

  tags = var.tags
}

# RDS 모듈 - 단일 AZ (비용 절감)
module "rds" {
  source = "../../modules/rds"

  identifier  = var.rds_identifier
  environment = "dev"

  # 데이터베이스 설정
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage

  # 네트워크 설정
  subnet_ids             = values(module.vpc.data_subnet_ids)
  vpc_security_group_ids = [module.security_groups.rds_sg_id]

  # 마스터 비밀번호 (Secrets Manager에서 자동 생성)
  create_random_password = true
  create_secrets_manager = true
  master_password        = "" # 자동 생성되므로 빈 문자열

  # 고가용성 설정
  multi_az = var.rds_multi_az

  # 백업 설정
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window

  # 성능 설정
  performance_insights_enabled = var.rds_performance_insights_enabled

  # 보안 설정
  storage_encrypted = true
  kms_key_id        = null

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

# EKS 클러스터 모듈
module "eks" {
  source = "../../modules/eks"

  name        = var.eks_name
  environment = "dev"
  region      = var.region
  vpc_id      = module.vpc.vpc_id

  # 네트워크 설정
  subnet_ids               = values(module.vpc.private_subnet_ids)
  control_plane_subnet_ids = values(module.vpc.public_subnet_ids)

  # 노드 그룹 설정 (Dev: 비용 최적화)
  node_group_instance_types = var.eks_node_instance_types # Dev: ["t3.medium"]
  node_group_capacity_type  = var.eks_node_capacity_type  # Dev: ON_DEMAND
  node_group_min_size       = var.eks_node_min_size       # Dev: 2
  node_group_max_size       = var.eks_node_max_size       # Dev: 5
  node_group_desired_size   = var.eks_node_desired_size   # Dev: 2

  # Kubernetes 버전
  cluster_version = var.eks_cluster_version # 1.34

  # Add-ons 설정
  enable_aws_load_balancer_controller = true
  enable_karpenter                    = false # Dev에서는 비활성화 (비용 절감)
  enable_ebs_csi_driver               = true

  tags = var.tags
}

# 통합 모니터링 모듈
module "monitoring" {
  source = "../../modules/monitoring"

  name   = var.eks_name
  region = var.region

  # 기존 리소스 연결
  alb_arn_suffix         = module.public_alb.alb_arn_suffix
  rds_instance_id        = module.rds.db_instance_id
  elasticache_cluster_id = module.elasticache.cluster_id

  # SNS 알림 비활성화 (Dev 환경)
  enable_sns_alerts = false

  tags = var.tags

  depends_on = [
    module.public_alb,
    module.management_alb,
    module.rds,
    module.elasticache
  ]
}
