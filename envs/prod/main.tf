provider "aws" {
  region = var.region
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
