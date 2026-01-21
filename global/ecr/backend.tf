terraform {
  backend "s3" {
    bucket         = "goorm-popcorn-tfstate"
    key            = "global/ecr/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goorm-popcorn-tfstate-lock"
    encrypt        = true
  }
}
