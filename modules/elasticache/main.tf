locals {
  replication_group_id = var.replication_group_id != "" ? var.replication_group_id : var.name
  enable_failover      = var.num_cache_clusters > 1 ? var.automatic_failover_enabled : false
  enable_multi_az      = var.num_cache_clusters > 1 ? var.multi_az_enabled : false
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-subnet-group" })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = local.replication_group_id
  description                = "Valkey replication group for ${var.name}"
  engine                     = "valkey"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_clusters
  port                       = var.port
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [var.security_group_id]
  automatic_failover_enabled = local.enable_failover
  multi_az_enabled           = local.enable_multi_az
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  
  # Valkey 최적화 설정
  apply_immediately = var.apply_immediately
  
  # 백업 설정
  snapshot_retention_limit = var.snapshot_retention_limit
  snapshot_window         = var.snapshot_window
  
  # 유지보수 설정
  maintenance_window = var.maintenance_window

  tags = merge(var.tags, { 
    Name   = var.name
    Engine = "valkey"
  })
}
