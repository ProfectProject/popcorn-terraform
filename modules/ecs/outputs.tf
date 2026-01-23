# ECS Fargate Module Outputs

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_arns" {
  description = "ARNs of the ECS services"
  value = {
    for k, v in aws_ecs_service.services : k => v.id
  }
}

output "service_names" {
  description = "Names of the ECS services"
  value = {
    for k, v in aws_ecs_service.services : k => v.name
  }
}

output "task_definition_arns" {
  description = "ARNs of the ECS task definitions"
  value = {
    for k, v in aws_ecs_task_definition.services : k => v.arn
  }
}

output "log_group_names" {
  description = "Names of the CloudWatch log groups"
  value = {
    for k, v in aws_cloudwatch_log_group.services : k => v.name
  }
}

output "autoscaling_target_arns" {
  description = "ARNs of the auto scaling targets"
  value = {
    for k, v in aws_appautoscaling_target.ecs_target : k => v.arn
  }
}