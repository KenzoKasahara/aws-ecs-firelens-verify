variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "vpc_id" {
  description = "ID of the existing VPC to deploy ECS tasks into"
  type        = string
}

variable "s3_bucket_suffix" {
  description = "Globally-unique suffix appended to the S3 bucket name (bucket = <project_name>-logs-<suffix>)"
  type        = string
}

variable "app_log_retention_days" {
  description = "CloudWatch Logs retention in days for the app log group"
  type        = number
}

variable "log_router_retention_days" {
  description = "CloudWatch Logs retention in days for the log_router (Fluent Bit) log group"
  type        = number
}

variable "task_cpu" {
  description = "ECS task CPU units (e.g. \"256\")"
  type        = string
}

variable "task_memory" {
  description = "ECS task memory in MiB (e.g. \"512\")"
  type        = string
}

variable "log_router_memory_limit" {
  description = "Hard memory limit in MiB for the log_router container. OOMKill occurs when Fluent Bit exceeds this value. Must be less than task_memory."
  type        = number
  default     = 200
}

