terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

module "vpc" {
  source = "../../modules/vpc"

  name = "goorm-popcorn-vpc"
  cidr = "10.0.0.0/16"

  public_subnets = [
    {
      name = "public-2a"
      az   = "ap-northeast-2a"
      cidr = "10.0.1.0/24"
    },
    {
      name = "public-2c"
      az   = "ap-northeast-2c"
      cidr = "10.0.2.0/24"
    }
  ]

  app_subnets = [
    {
      name = "private-app-2a"
      az   = "ap-northeast-2a"
      cidr = "10.0.11.0/24"
    },
    {
      name = "private-app-2c"
      az   = "ap-northeast-2c"
      cidr = "10.0.12.0/24"
    }
  ]

  data_subnets = [
    {
      name = "private-data-2a"
      az   = "ap-northeast-2a"
      cidr = "10.0.21.0/24"
    },
    {
      name = "private-data-2c"
      az   = "ap-northeast-2c"
      cidr = "10.0.22.0/24"
    }
  ]
}
