# ECS Fargate Module
# Supports both dev (single AZ) and prod (multi AZ) configurations

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  base_tags  = merge({ Name = var.name }, var.tags)
  account_id = var.account_id != null ? var.account_id : data.aws_caller_identity.current.account_id

  # ECR 이미지 URL 매핑 (동적 태그 지원)
  service_images = {
    for service_name in var.service_names : service_name => (
      contains(keys(var.ecr_repositories), service_name) ?
      "${var.ecr_repositories[service_name]}:${var.image_tag}" :
      "${var.ecr_repository_url}/${var.name}/${service_name}:${var.image_tag}"
    )
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.name}-cluster"

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(local.base_tags, {
    Name = "${var.name}-cluster"
  })
}

# CloudWatch Log Group for ECS Exec
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${var.name}/exec"
  retention_in_days = var.log_retention_days

  tags = merge(local.base_tags, {
    Name = "${var.name}-ecs-exec-logs"
  })
}

# Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    base              = 0
    weight            = var.environment == "prod" ? 3 : 1
    capacity_provider = "FARGATE_SPOT"
  }
}

# CloudWatch Log Groups for Services
resource "aws_cloudwatch_log_group" "services" {
  for_each = toset(var.service_names)

  name              = "/aws/ecs/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = merge(local.base_tags, {
    Name    = "${var.name}-${each.key}-logs"
    Service = each.key
  })
}

# Task Definitions
resource "aws_ecs_task_definition" "services" {
  for_each = var.services

  family                   = "${var.name}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn

  container_definitions = jsonencode([
    {
      name  = each.key
      image = local.service_images[each.key]

      portMappings = [
        {
          containerPort = each.key == "payment-front" ? 3000 : 8080
          protocol      = "tcp"
        }
      ]

      environment = concat(
        each.value.environment_variables,
        var.elasticache_primary_endpoint != null ? [
          {
            name  = "REDIS_PRIMARY_ENDPOINT"
            value = var.elasticache_primary_endpoint
          },
          {
            name  = "REDIS_READER_ENDPOINT"
            value = var.elasticache_reader_endpoint != null ? var.elasticache_reader_endpoint : var.elasticache_primary_endpoint
          },
          {
            name  = "REDIS_PORT"
            value = "6379"
          }
        ] : [],
        var.database_endpoint != null ? [
          {
            name  = "DB_HOST"
            value = var.database_endpoint
          },
          {
            name  = "DB_PORT"
            value = tostring(var.database_port)
          },
          {
            name  = "DB_NAME"
            value = var.database_name
          }
        ] : [],
        var.kafka_bootstrap_servers != null ? [
          {
            name  = "KAFKA_BOOTSTRAP_SERVERS"
            value = var.kafka_bootstrap_servers
          }
        ] : []
      )

      secrets = var.database_secret_arn != null ? [
        {
          name      = "DB_PASSWORD"
          valueFrom = var.database_secret_arn
        }
      ] : []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/aws/ecs/${var.name}/${each.key}"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command = each.key == "payment-front" ? [
          "CMD-SHELL",
          "curl -f http://localhost:3000/health || exit 1"
        ] : [
          "CMD-SHELL",
          "curl -f http://localhost:8080/actuator/health || exit 1"
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = merge(local.base_tags, {
    Name    = "${var.name}-${each.key}-task"
    Service = each.key
  })
}

# ECS Services
resource "aws_ecs_service" "services" {
  for_each = var.services

  name            = "${var.name}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = each.value.desired_count

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = each.value.min_capacity
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.environment == "prod" ? 3 : 1
    base              = 0
  }

  network_configuration {
    security_groups  = [var.security_group_id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.key == "api-gateway" && var.alb_target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.alb_target_group_arn
      container_name   = each.key
      container_port   = 8080
    }
  }

  dynamic "load_balancer" {
    for_each = each.key == "payment-front" && var.payment_front_target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.payment_front_target_group_arn
      container_name   = each.key
      container_port   = 3000
    }
  }

  dynamic "service_registries" {
    for_each = lookup(var.service_discovery_service_arns, each.key, null) != null ? [1] : []
    content {
      registry_arn = var.service_discovery_service_arns[each.key]
    }
  }

  enable_execute_command = true

  depends_on = [var.alb_listener_arn]

  tags = merge(local.base_tags, {
    Name    = "${var.name}-${each.key}-service"
    Service = each.key
  })

  # CI/CD가 배포/스케일을 관리할 때 드리프트 방지
  lifecycle {
    ignore_changes = [
      task_definition,
      desired_count
    ]
  }
}

# Auto Scaling Targets
resource "aws_appautoscaling_target" "ecs_target" {
  for_each = var.services

  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.base_tags, {
    Name    = "${var.name}-${each.key}-autoscaling-target"
    Service = each.key
  })
}

# Auto Scaling Policies - CPU
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  for_each = var.services

  name               = "${var.name}-${each.key}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = each.value.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

# Auto Scaling Policies - Memory
resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  for_each = var.services

  name               = "${var.name}-${each.key}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = each.value.memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}
