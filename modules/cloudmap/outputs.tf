# CloudMap Service Discovery Module Outputs

output "namespace_id" {
  description = "ID of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "namespace_arn" {
  description = "ARN of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "namespace_name" {
  description = "Name of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_arns" {
  description = "ARNs of the service discovery services"
  value = {
    for k, v in aws_service_discovery_service.services : k => v.arn
  }
}

output "service_ids" {
  description = "IDs of the service discovery services"
  value = {
    for k, v in aws_service_discovery_service.services : k => v.id
  }
}

output "service_names" {
  description = "Names of the service discovery services"
  value = {
    for k, v in aws_service_discovery_service.services : k => v.name
  }
}