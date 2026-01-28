provider "aws" {
  region = "ap-northeast-2"
}

# ECR Repositories for all microservices
resource "aws_ecr_repository" "repositories" {
  for_each = toset([
    "goorm-popcorn-api-gateway",
    "goorm-popcorn-user",
    "goorm-popcorn-store",
    "goorm-popcorn-order",
    "goorm-popcorn-payment",
    "goorm-popcorn-payment-front",
    "goorm-popcorn-checkin",
    "goorm-popcorn-order-query"
  ])

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = each.value
    Environment = "global"
    ManagedBy   = "terraform"
  }
}
