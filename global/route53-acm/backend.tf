terraform {
  backend "s3" {
    bucket         = "goorm-popcorn-tfstate"
    key            = "global/route53-acm/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goorm-popcorn-tfstate-lock"
    encrypt        = true
  }
}
