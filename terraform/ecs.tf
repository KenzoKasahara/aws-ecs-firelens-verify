resource "aws_ecs_cluster" "verify" {
  name = var.project_name

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}

locals {
  # 検証3（filesystem）と検証1/2/4（memory）で log_router の構成を切り替える。
  log_router_image = var.enable_filesystem_buffer ? "${aws_ecr_repository.log_router.repository_url}:fs" : "${aws_ecr_repository.log_router.repository_url}:latest"

  # filesystem モードは Dockerfile.fs の CMD で自前設定を読むため config-file-value は不要（空 options）。
  # memory モードは extra.conf を @INCLUDE する。
  log_router_firelens_options = var.enable_filesystem_buffer ? {} : {
    "config-file-type"  = "file"
    "config-file-value" = "/fluent-bit/configs/extra.conf"
  }

  # filesystem モードのフル設定は APP_LOG_GROUP を、memory モードの extra.conf は S3_BUCKET_NAME を参照する。
  log_router_environment = var.enable_filesystem_buffer ? [
    { name = "AWS_REGION", value = var.aws_region },
    { name = "APP_LOG_GROUP", value = aws_cloudwatch_log_group.app.name },
    ] : [
    { name = "AWS_REGION", value = var.aws_region },
    { name = "S3_BUCKET_NAME", value = aws_s3_bucket.verify_logs.id },
  ]
}

resource "aws_ecs_task_definition" "verify" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn

  # FireLens サイドカーを先に起動するため、log_router は app より前に定義する。
  container_definitions = jsonencode([
    {
      name      = "log_router"
      image     = local.log_router_image
      memory    = var.log_router_memory_limit
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_router.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "fb"
        }
      }
      firelensConfiguration = {
        # memory モード: extra.conf を @INCLUDE してベース設定に S3 OUTPUT を追加（Fargate は file 方式のみ）。
        # filesystem モード: options を空にし、Dockerfile.fs の CMD 上書きで自前フル設定を読む。
        type    = "fluentbit"
        options = local.log_router_firelens_options
      }
      environment = local.log_router_environment

    },
    {
      name      = "app"
      image     = "httpd:2.4"
      essential = true
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name              = "cloudwatch_logs"
          region            = var.aws_region
          log_group_name    = aws_cloudwatch_log_group.app.name
          auto_create_group = "false"
          log_stream_prefix = "app-"
          # Docker → Fluent Bit 間のバッファ行数。超過分は Docker が破棄（検証2 の欠落点）。
          # Fluent Bit 設定ではなく Docker ドライバの設定なので、filesystem モードでも有効。
          "log-driver-buffer-limit" = tostring(var.app_log_driver_buffer_limit)
        }
      }
    }
  ])

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}
