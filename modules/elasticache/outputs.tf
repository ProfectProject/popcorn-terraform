output "replication_group_id" {
  description = "ID of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.main.replication_group_id
}

output "primary_endpoint_address" {
  description = "Address of the primary endpoint"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Address of the reader endpoint"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "port" {
  description = "Port of the ElastiCache cluster"
  value       = aws_elasticache_replication_group.main.port
}

output "configuration_endpoint_address" {
  description = "Address of the configuration endpoint"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}