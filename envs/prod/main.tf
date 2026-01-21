provider "aws" {
  region = var.region
}

data "terraform_remote_state" "global_route53_acm" {
  backend = "s3"

  config = {
    bucket = "goorm-popcorn-tfstate"
    key    = "global/route53-acm/terraform.tfstate"
    region = var.region
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = var.vpc_name
  cidr               = var.vpc_cidr
  public_subnets     = var.public_subnets
  app_subnets        = var.app_subnets
  data_subnets       = var.data_subnets
  enable_nat         = var.enable_nat
  single_nat_gateway = var.single_nat_gateway
}

module "security_groups" {
  source = "../../modules/security-groups"
  name   = var.sg_name
  vpc_id = module.vpc.vpc_id
}

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
