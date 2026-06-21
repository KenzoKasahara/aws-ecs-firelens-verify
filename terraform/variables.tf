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

variable "enable_filesystem_buffer" {
  description = "検証3 用トグル。true で log_router を filesystem バッファ構成（:fs イメージ + フル設定の CMD 上書き）に切り替える。false（既定）は memory バッファ + extra.conf @INCLUDE 方式。運用時は terraform.tfvars で切り替える。"
  type        = bool
  default     = false
}

variable "app_log_driver_buffer_limit" {
  description = "app コンテナの awsfirelens ログドライバが Fluent Bit へ渡す前にメモリ保持するログ行数（Docker fluentd ドライバの log-driver-buffer-limit）。AWS 既定は 1048576 行。超過分は Docker が破棄する。検証2 では terraform.tfvars で『FB forward input のメモリバッファ容量（行数換算）より大きく、かつ投入量より十分小さい値』（実測では 8192 で再現）にする。小さすぎると Docker 段で先に破棄され mem buf overlimit が出ず、大きすぎると破棄されず欠落しない。検証3（filesystem）は input が pause せずバッファが溜まらないため破棄は起きない。"
  type        = number
  default     = 1048576
}

