# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_data_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# Aurora Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "main" {
  family      = "aurora-postgresql15"
  name        = "${var.project_name}-cluster-pg"
  description = "Aurora cluster parameter group for ${var.project_name}"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = var.tags
}

# Aurora DB Parameter Group
resource "aws_db_parameter_group" "main" {
  family = "aurora-postgresql15"
  name   = "${var.project_name}-db-pg"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = var.tags
}

# Random password for master user
resource "random_password" "master" {
  length  = 16
  special = true
}

# Store master password in Secrets Manager
resource "aws_secretsmanager_secret" "db_master_password" {
  name                    = "${var.project_name}/${var.environment}/db/master-password"
  description             = "Master password for Aurora PostgreSQL cluster"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_master_password" {
  secret_id     = aws_secretsmanager_secret.db_master_password.id
  secret_string = random_password.master.result
}

# Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier      = "${var.project_name}-aurora-cluster"
  engine                 = "aurora-postgresql"
  engine_version         = var.engine_version
  database_name          = var.database_name
  master_username        = var.master_username
  master_password        = random_password.master.result
  
  backup_retention_period = var.backup_retention_period
  preferred_backup_window = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  db_subnet_group_name           = aws_db_subnet_group.main.name
  vpc_security_group_ids         = [var.aurora_security_group_id]
  
  storage_encrypted = true
  kms_key_id       = var.kms_key_id
  
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null
  
  deletion_protection = var.environment == "prod"
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-cluster"
  })
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "cluster_instances" {
  count              = var.instance_count
  identifier         = "${var.project_name}-aurora-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  
  db_parameter_group_name = aws_db_parameter_group.main.name
  
  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval         = var.monitoring_interval
  monitoring_role_arn        = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-${count.index}"
  })
}

# Enhanced Monitoring Role
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.project_name}-rds-enhanced-monitoring"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "aurora_read_replica" {
  count              = var.enable_autoscaling ? 1 : 0
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "cluster:${aws_rds_cluster.main.cluster_identifier}"
  scalable_dimension = "rds:cluster:ReadReplicaCount"
  service_namespace  = "rds"

  tags = var.tags
}

# Auto Scaling Policy
resource "aws_appautoscaling_policy" "aurora_read_replica" {
  count              = var.enable_autoscaling ? 1 : 0
  name               = "${var.project_name}-aurora-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.aurora_read_replica[0].resource_id
  scalable_dimension = aws_appautoscaling_target.aurora_read_replica[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.aurora_read_replica[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }

    target_value       = var.autoscaling_target_cpu
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}