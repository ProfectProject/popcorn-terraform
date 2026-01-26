provider "aws" {
  region = "ap-northeast-2"
}

# ECR Repositories for all microservices
resource "aws_ecr_repository" "repositories" {
  for_each = toset([
    "goorm-popcorn-order",
    "goorm-popcorn-order-query", 
    "goorm-popcorn-payment",
    "goorm-popcorn-api-gateway",
    "goorm-popcorn-qr",
    "goorm-popcorn-store",
    "goorm-popcorn-user",
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
