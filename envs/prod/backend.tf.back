terraform {
  backend "s3" {
    bucket         = "goorm-popcorn-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goorm-popcorn-tfstate-lock"
    encrypt        = true
  }
}
