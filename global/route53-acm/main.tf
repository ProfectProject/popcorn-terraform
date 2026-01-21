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
