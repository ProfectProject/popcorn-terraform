# Dev Environment RDS Configuration
# 단일 AZ, 최소 스펙, 비용 최적화

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name_prefix}-db-password"
  description             = "RDS PostgreSQL password for ${local.environment}"
  recovery_window_in_days = 0 # 즉시 삭제 (dev 환경)

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.db_password.result
  })
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
  instance_class = "db.t4g.micro" # 최저 스펙

  # Storage Configuration
  allocated_storage     = 20  # 최소 스토리지
  max_allocated_storage = 50  # 자동 확장 제한
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database Configuration
  database_name   = "popcorn_dev"
  master_username = "postgres"
  master_password = random_password.db_password.result

  # Network Configuration
  subnet_ids             = module.vpc.database_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # High Availability Configuration (Dev: 단일 AZ)
  multi_az          = false
  availability_zone = data.aws_availability_zones.available.names[0] # ap-northeast-2a

  # Backup Configuration (Dev: 최소 백업)
  backup_retention_period = 1 # 1일만 보존
  backup_window          = "03:00-04:00"
  copy_tags_to_snapshot  = true
  delete_automated_backups = true

  # Maintenance Configuration
  maintenance_window         = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade = true

  # Parameter Configuration (개발 환경 최적화)
  db_parameters = [
    {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    },
    {
      name  = "log_statement"
      value = "ddl" # DDL만 로깅 (비용 절약)
    },
    {
      name  = "log_min_duration_statement"
      value = "5000" # 5초 이상 쿼리만 로깅
    },
    {
      name  = "log_connections"
      value = "0" # 연결 로그 비활성화
    },
    {
      name  = "log_disconnections"
      value = "0" # 연결 해제 로그 비활성화
    },
    {
      name  = "max_connections"
      value = "100" # 연결 수 제한
    }
  ]

  # Monitoring Configuration (기본 모니터링)
  monitoring_interval = 0 # Enhanced Monitoring 비활성화 (비용 절약)

  # Performance Insights (비활성화)
  performance_insights_enabled = false

  # Deletion Protection (Dev: 비활성화)
  deletion_protection = false
  skip_final_snapshot = true # 최종 스냅샷 생략

  # CloudWatch Logs (최소화)
  enabled_cloudwatch_logs_exports = ["postgresql"]
  cloudwatch_log_retention       = 3 # 3일만 보존

  # Apply Changes (Dev: 즉시 적용)
  apply_immediately = true

  # Read Replica (Dev: 비활성화)
  create_read_replica = false

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

  # 관리용 접근 (Bastion 또는 VPN)
  ingress {
    description = "PostgreSQL from management"
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

# CloudWatch Alarms for RDS (기본적인 알람만)
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80" # Dev: 높은 임계값
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [] # Dev: 알람 액션 없음

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
  threshold           = "80" # max_connections의 80%
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = [] # Dev: 알람 액션 없음

  dimensions = {
    DBInstanceIdentifier = module.rds.db_instance_id
  }

  tags = local.common_tags
}