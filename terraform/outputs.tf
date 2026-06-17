output "ecs_cluster_name" {
  description = "ECS cluster name (use in aws ecs run-task / update-service)"
  value       = aws_ecs_cluster.verify.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.verify.arn
}

output "task_definition_arn" {
  description = "Latest active task definition ARN"
  value       = aws_ecs_task_definition.verify.arn
}

output "task_definition_family" {
  description = "Task definition family name"
  value       = aws_ecs_task_definition.verify.family
}

output "task_security_group_id" {
  description = "Security group ID to specify in --network-configuration when running tasks"
  value       = aws_security_group.task.id
}

output "task_role_arn" {
  description = "IAM Task Role ARN"
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "IAM Execution Role ARN"
  value       = aws_iam_role.execution.arn
}

output "app_log_group_name" {
  description = "CloudWatch Logs group for app container output"
  value       = aws_cloudwatch_log_group.app.name
}

output "log_router_log_group_name" {
  description = "CloudWatch Logs group for Fluent Bit (log_router) own logs"
  value       = aws_cloudwatch_log_group.log_router.name
}

output "s3_bucket_name" {
  description = "S3 bucket for multi-destination log routing verification"
  value       = aws_s3_bucket.verify_logs.id
}

output "task_policy_arn" {
  description = "IAM Task Policy ARN"
  value       = aws_iam_policy.task_policy.arn
}

output "vpc_id" {
  description = "VPC ID used for ECS task networking (use to look up subnet IDs)"
  value       = var.vpc_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for custom log_router images (used in verification scenarios 2/4/6)"
  value       = aws_ecr_repository.log_router.repository_url
}
