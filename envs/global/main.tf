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

module "route53_acm" {
  source = "../../modules/route53-acm"

  zone_name = "goormpopcorn.shop"
  subject_alternative_names = [
    "*.goormpopcorn.shop",
  ]
}
