provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../../modules/vpc"

  name            = var.vpc_name
  cidr            = var.vpc_cidr
  public_subnets  = var.public_subnets
  app_subnets     = var.app_subnets
  data_subnets    = var.data_subnets
  nat_gateway_ids = module.nat.nat_gateway_ids
}

module "security_groups" {
  source = "../../modules/security-groups"

  name   = var.sg_name
  vpc_id = module.vpc.vpc_id
}

module "nat" {
  source = "../../modules/nat"

  name           = var.vpc_name
  public_subnets = var.public_subnets
  nat_azs        = var.nat_azs
}
