# MSK Serverless Cluster
resource "aws_msk_serverless_cluster" "main" {
  cluster_name = "${var.project_name}-msk-serverless"

  vpc_config {
    subnet_ids         = var.private_app_subnet_ids
    security_group_ids = [var.msk_security_group_id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-msk-serverless"
  })
}

# CloudWatch Log Group for MSK
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Alarms for MSK
resource "aws_cloudwatch_metric_alarm" "msk_cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-msk-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CpuUser"
  namespace           = "AWS/Kafka"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors MSK CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    "Cluster Name" = aws_msk_serverless_cluster.main.cluster_name
  }

  tags = var.tags
}

# IAM Policy for MSK Access
resource "aws_iam_policy" "msk_access" {
  name        = "${var.project_name}-msk-access-policy"
  description = "Policy for MSK Serverless access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:DescribeCluster"
        ]
        Resource = aws_msk_serverless_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:*Topic*",
          "kafka-cluster:WriteData",
          "kafka-cluster:ReadData"
        ]
        Resource = "${aws_msk_serverless_cluster.main.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeGroup"
        ]
        Resource = "${aws_msk_serverless_cluster.main.arn}/*"
      }
    ]
  })

  tags = var.tags
}

# Store MSK connection details in Secrets Manager
resource "aws_secretsmanager_secret" "msk_config" {
  name                    = "${var.project_name}/${var.environment}/msk/config"
  description             = "MSK Serverless configuration"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "msk_config" {
  secret_id = aws_secretsmanager_secret.msk_config.id
  secret_string = jsonencode({
    bootstrap_servers = aws_msk_serverless_cluster.main.bootstrap_brokers_sasl_iam
    cluster_arn      = aws_msk_serverless_cluster.main.arn
    security_protocol = "SASL_SSL"
    sasl_mechanism   = "AWS_MSK_IAM"
    topics = {
      order_created        = "order-created"
      order_confirmed      = "order-confirmed"
      payment_completed    = "payment-completed"
      notification_request = "notification-request"
      notification_sent    = "notification-sent"
    }
  })
}