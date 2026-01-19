locals {
  repo_names = toset(var.repositories)
}

resource "aws_ecr_repository" "this" {
  for_each = local.repo_names

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = each.value })
}
