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
  enable_access_logs       = false # S3 비용 절약을 위해 비활성화

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
  enable_access_logs       = false # S3 비용 절약을 위해 비활성화

  tags = var.tags
}

# Route53 레코드 - Public ALB (Frontend 서비스)
resource "aws_route53_record" "main" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.public_alb.alb_dns_name
    zone_id                = module.public_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "api" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "api.goormpopcorn.shop"
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
  name    = "kafka.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "argocd" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "argocd.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "grafana" {
  zone_id = data.terraform_remote_state.global_route53_acm.outputs.zone_id
  name    = "grafana.goormpopcorn.shop"
  type    = "A"

  alias {
    name                   = module.management_alb.alb_dns_name
    zone_id                = module.management_alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Route53 헬스체크 - Management ALB 서브도메인
resource "aws_route53_health_check" "kafka" {
  fqdn              = "kafka.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "kafka-goormpopcorn-shop-health-check"
  })
}

resource "aws_route53_health_check" "argocd" {
  fqdn              = "argocd.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "argocd-goormpopcorn-shop-health-check"
  })
}

resource "aws_route53_health_check" "grafana" {
  fqdn              = "grafana.goormpopcorn.shop"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "grafana-goormpopcorn-shop-health-check"
  })
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

# 통합 모니터링 모듈 (SNS 없이)
module "monitoring" {
  source = "../../modules/monitoring"

  name   = var.eks_name
  region = var.region

  # 기존 리소스 연결 - Public ALB와 Management ALB 모두 모니터링
  alb_arn_suffix         = module.public_alb.alb_arn_suffix
  rds_instance_id        = module.rds.db_instance_id
  elasticache_cluster_id = module.elasticache.cluster_id

  # SNS 알림 비활성화 (기본값)
  enable_sns_alerts = false

  tags = var.tags

  depends_on = [
    module.public_alb,
    module.management_alb,
    module.rds,
    module.elasticache
  ]
}
