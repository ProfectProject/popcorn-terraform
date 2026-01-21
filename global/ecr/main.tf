provider "aws" {
  region = "ap-northeast-2"
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = [
    "goorm-popcorn-order",
    "goorm-popcorn-order-query",
    "goorm-popcorn-payment",
    "goorm-popcorn-qr",
    "goorm-popcorn-store",
    "goorm-popcorn-user",
  ]
}
