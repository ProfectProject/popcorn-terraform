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

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  for_each   = aws_ecr_repository.repositories
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete dev tagged images after 30 days"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev"]
          countType     = "sinceImagePushed"
          countUnit     = "days"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
      # prod 태그는 영구 보관 (별도 규칙 없음)
    ]
  })
}
