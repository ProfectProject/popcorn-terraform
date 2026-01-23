# EC2 Kafka Module Outputs

output "instance_ids" {
  description = "List of Kafka instance IDs"
  value       = aws_instance.kafka[*].id
}

output "private_ips" {
  description = "List of private IP addresses"
  value       = aws_instance.kafka[*].private_ip
}

output "public_ips" {
  description = "List of public IP addresses (if any)"
  value       = aws_instance.kafka[*].public_ip
}

output "cluster_id" {
  description = "Kafka cluster ID"
  value       = random_uuid.cluster_id.result
}

output "bootstrap_servers" {
  description = "Kafka bootstrap servers connection string"
  value       = join(",", [for ip in aws_instance.kafka[*].private_ip : "${ip}:9092"])
}

output "dns_names" {
  description = "List of DNS names (if created)"
  value       = var.create_dns_records ? aws_route53_record.kafka[*].fqdn : []
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.kafka.name
}

output "security_group_id" {
  description = "Security group ID used by Kafka instances"
  value       = var.security_group_id
}