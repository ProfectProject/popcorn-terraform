# RDS PostgreSQL Module
# 모든 환경에서 RDS PostgreSQL 사용
# Dev: 단일 AZ, Prod: Multi-AZ 구성

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  family = var.parameter_group_family
  name   = "${var.identifier}-params"

  # PostgreSQL 최적화 파라미터
  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name  = parameter.value.name
      value = parameter.value.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-parameter-group"
  })
}

# DB Option Group (PostgreSQL은 필요 시에만)
resource "aws_db_option_group" "main" {
  count = var.create_option_group ? 1 : 0

  name                     = "${var.identifier}-options"
  option_group_description = "Option group for ${var.identifier}"
  engine_name              = var.engine
  major_engine_version     = var.major_engine_version

  tags = merge(var.tags, {
    Name = "${var.identifier}-option-group"
  })
}

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  count = var.kms_key_id == null ? 1 : 0

  description             = "RDS encryption key for ${var.identifier}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.identifier}-rds-encryption-key"
  })
}

resource "aws_kms_alias" "rds" {
  count = var.kms_key_id == null ? 1 : 0

  name          = "alias/${var.identifier}-rds-encryption-key"
  target_key_id = aws_kms_key.rds[0].key_id
}

# RDS Instance
resource "aws_db_instance" "main" {
  # Basic Configuration
  identifier = var.identifier
  
  # Engine Configuration
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  
  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id           = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.rds[0].arn
  
  # Database Configuration
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password
  port     = var.database_port
  
  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  
  # High Availability Configuration
  multi_az               = var.multi_az
  availability_zone      = var.multi_az ? null : var.availability_zone
  
  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window          = var.backup_window
  copy_tags_to_snapshot  = var.copy_tags_to_snapshot
  delete_automated_backups = var.delete_automated_backups
  
  # Maintenance Configuration
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  
  # Parameter and Option Groups
  parameter_group_name = aws_db_parameter_group.main.name
  option_group_name    = var.create_option_group ? aws_db_option_group.main[0].name : null
  
  # Monitoring Configuration
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? var.monitoring_role_arn : null
  
  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id      = var.performance_insights_enabled ? (var.performance_insights_kms_key_id != null ? var.performance_insights_kms_key_id : aws_kms_key.rds[0].arn) : null
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  
  # Deletion Protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Log Exports
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  
  # Apply changes immediately (for non-production)
  apply_immediately = var.apply_immediately
  
  # Lifecycle
  lifecycle {
    ignore_changes = [
      password, # 패스워드 변경 시 무시
      final_snapshot_identifier, # 스냅샷 이름 변경 무시
    ]
  }

  tags = merge(var.tags, {
    Name = var.identifier
  })
}

# CloudWatch Log Groups for RDS logs
resource "aws_cloudwatch_log_group" "postgresql" {
  for_each = toset(var.enabled_cloudwatch_logs_exports)

  name              = "/aws/rds/instance/${var.identifier}/${each.value}"
  retention_in_days = var.cloudwatch_log_retention
  kms_key_id        = var.kms_key_id != null ? var.kms_key_id : aws_kms_key.rds[0].arn

  tags = merge(var.tags, {
    Name = "${var.identifier}-${each.value}-logs"
  })
}

# Read Replicas (선택적)
resource "aws_db_instance" "read_replica" {
  count = var.create_read_replica ? var.read_replica_count : 0

  identifier = "${var.identifier}-read-replica-${count.index + 1}"
  
  # Replica Configuration
  replicate_source_db = aws_db_instance.main.identifier
  
  # Instance Configuration
  instance_class = var.read_replica_instance_class != null ? var.read_replica_instance_class : var.instance_class
  
  # Network Configuration
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  
  # Availability Zone (다른 AZ에 배치)
  availability_zone = var.read_replica_availability_zones != null ? var.read_replica_availability_zones[count.index] : null
  
  # Monitoring
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? var.monitoring_role_arn : null
  
  # Performance Insights
  performance_insights_enabled = var.performance_insights_enabled
  
  # Maintenance
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  maintenance_window         = var.maintenance_window
  
  # Apply changes immediately
  apply_immediately = var.apply_immediately
  
  # Deletion Protection
  deletion_protection = var.deletion_protection
  skip_final_snapshot = true # Read replica는 final snapshot 불필요
  
  tags = merge(var.tags, {
    Name = "${var.identifier}-read-replica-${count.index + 1}"
    Type = "ReadReplica"
  })
}