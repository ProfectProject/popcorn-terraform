# Production Environment RDS Configuration
# Multi-AZ, 고가용성, 최저 스펙으로 비용 최적화

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name_prefix}-db-password"
  description             = "RDS PostgreSQL password for ${local.environment}"
  recovery_window_in_days = 7 # 7일 복구 기간

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.db_password.result
  })
}

# Enhanced Monitoring IAM Role
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${local.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS PostgreSQL Instance
module "rds" {
  source = "../../modules/rds"

  # Basic Configuration
  identifier  = "${local.name_prefix}-postgres"
  environment = local.environment

  # Engine Configuration
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.micro" # 최저 스펙 (Dev와 동일)

  # Storage Configuration
  allocated_storage     = 20   # 최소 스토리지
  max_allocated_storage = 200  # 자동 확장 한도 증가
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database Configuration
  database_name   = "popcorn_prod"
  master_username = "postgres"
  master_password = random_password.db_password.result

  # Network Configuration
  subnet_ids             = module.vpc.database_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability Configuration (Prod: Multi-AZ)
  multi_az = true # 고가용성 확보

  # Backup Configuration (Prod: 강화된 백업)
  backup_retention_period = 7 # 7일 보존
  backup_window          = "03:00-04:00"
  copy_tags_to_snapshot  = true
  delete_automated_backups = false # 자동 백업 보존

  # Maintenance Configuration
  maintenance_window         = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade = true

  # Parameter Configuration (프로덕션 환경 최적화)
  db_parameters = [
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    },
    {
      name  = "log_statement"
      value = "mod" # DML 로깅
    },
    {
      name  = "log_min_duration_statement"
      value = "1000" # 1초 이상 쿼리 로깅
    },
    {
      name  = "log_connections"
      value = "1" # 연결 로그 활성화
    },
    {
      name  = "log_disconnections"
      value = "1" # 연결 해제 로그 활성화
    },
    {
      name  = "max_connections"
      value = "200" # 연결 수 증가
    },
    {
      name  = "shared_buffers"
      value = "{DBInstanceClassMemory/32768}" # 메모리 최적화
    },
    {
      name  = "effective_cache_size"
      value = "{DBInstanceClassMemory*3/4/8192}" # 캐시 최적화
    },
    {
      name  = "checkpoint_completion_target"
      value = "0.9" # 체크포인트 최적화
    },
    {
      name  = "wal_buffers"
      value = "16MB" # WAL 버퍼 최적화
    }
  ]

  # Monitoring Configuration (Enhanced Monitoring 활성화)
  monitoring_interval = 60 # 1분 간격
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights (활성화)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # 7일 보존

  # Deletion Protection (Prod: 활성화)
  deletion_protection = true
  skip_final_snapshot = false # 최종 스냅샷 생성

  # CloudWatch Logs (전체 로그)
  enabled_cloudwatch_logs_exports = ["postgresql"]
  cloudwatch_log_retention       = 7 # 7일 보존

  # Apply Changes (Prod: 유지보수 시간에 적용)
  apply_immediately = false

  # Read Replica (필요 시 활성화)
  create_read_replica = false # 초기에는 비활성화, 필요 시 활성화
  read_replica_count  = 1

  tags = local.common_tags
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-rds-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for RDS PostgreSQL"

  # PostgreSQL 접근 (EKS 노드에서만)
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  # PostgreSQL 접근 (Kafka에서 CDC용)
  ingress {
    description     = "PostgreSQL from Kafka"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.kafka.id]
  }

  # 관리용 접근 (VPC 내부만)
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

# SNS Topic for RDS Alarms
resource "aws_sns_topic" "rds_alerts" {
  name = "${local.name_prefix}-rds-alerts"

  tags = local.common_tags
}

# CloudWatch Alarms for RDS (프로덕션용 강화된 모니터링)
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "70" # Prod: 낮은 임계값
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.rds_alerts.arn]
  ok_actions          = [aws_sns_topic.rds_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${local.name_prefix}-rds-database-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "160" # max_connections의 80%
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = [aws_sns_topic.rds_alerts.arn]
  ok_actions          = [aws_sns_topic.rds_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name_prefix}-rds-free-storage-space"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [aws_sns_topic.rds_alerts.arn]
  ok_actions          = [aws_sns_topic.rds_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_read_latency" {
  alarm_name          = "${local.name_prefix}-rds-read-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.2" # 200ms
  alarm_description   = "This metric monitors RDS read latency"
  alarm_actions       = [aws_sns_topic.rds_alerts.arn]
  ok_actions          = [aws_sns_topic.rds_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_write_latency" {
  alarm_name          = "${local.name_prefix}-rds-write-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.2" # 200ms
  alarm_description   = "This metric monitors RDS write latency"
  alarm_actions       = [aws_sns_topic.rds_alerts.arn]
  ok_actions          = [aws_sns_topic.rds_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  tags = local.common_tags
}