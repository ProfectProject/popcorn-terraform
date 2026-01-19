output "namespace_id" {
  description = "ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "namespace_arn" {
  description = "ARN of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "namespace_name" {
  description = "Name of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_arns" {
  description = "ARNs of the service discovery services"
  value = {
    api_gateway     = aws_service_discovery_service.api_gateway.arn
    user_service    = aws_service_discovery_service.user_service.arn
    store_service   = aws_service_discovery_service.store_service.arn
    order_service   = aws_service_discovery_service.order_service.arn
    payment_service = aws_service_discovery_service.payment_service.arn
    qr_service      = aws_service_discovery_service.qr_service.arn
  }
}

output "service_ids" {
  description = "IDs of the service discovery services"
  value = {
    api_gateway     = aws_service_discovery_service.api_gateway.id
    user_service    = aws_service_discovery_service.user_service.id
    store_service   = aws_service_discovery_service.store_service.id
    order_service   = aws_service_discovery_service.order_service.id
    payment_service = aws_service_discovery_service.payment_service.id
    qr_service      = aws_service_discovery_service.qr_service.id
  }
}