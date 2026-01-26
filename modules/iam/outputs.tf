# IAM Module Outputs

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task.name
}

output "ecs_autoscaling_role_arn" {
  description = "ARN of the ECS autoscaling role"
  value       = aws_iam_role.ecs_autoscaling.arn
}

output "ecs_autoscaling_role_name" {
  description = "Name of the ECS autoscaling role"
  value       = aws_iam_role.ecs_autoscaling.name
}
output "ec2_ssm_role_arn" {
  description = "ARN of the EC2 SSM role"
  value       = aws_iam_role.ec2_ssm.arn
}

output "ec2_ssm_role_name" {
  description = "Name of the EC2 SSM role"
  value       = aws_iam_role.ec2_ssm.name
}

output "ec2_ssm_instance_profile_name" {
  description = "Name of the EC2 SSM instance profile"
  value       = aws_iam_instance_profile.ec2_ssm.name
}