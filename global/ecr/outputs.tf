output "repository_urls" {
  description = "URLs of the ECR repositories"
  value = {
    for k, v in aws_ecr_repository.repositories : k => v.repository_url
  }
}

output "repository_arns" {
  description = "ARNs of the ECR repositories"
  value = {
    for k, v in aws_ecr_repository.repositories : k => v.arn
  }
}

output "registry_id" {
  description = "Registry ID"
  value = aws_ecr_repository.repositories["api-gateway"].registry_id
}