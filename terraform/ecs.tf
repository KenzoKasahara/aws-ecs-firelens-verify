resource "aws_ecs_cluster" "verify" {
  name = var.project_name

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
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
      image     = "${aws_ecr_repository.log_router.repository_url}:latest"
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
        type = "fluentbit"
        options = {
          # extra.conf を @INCLUDE してベース設定に S3 OUTPUT を追加する。
          # Fargate は config-file-type = "s3" 非サポートのため file 方式でイメージに同梱。
          "config-file-type"  = "file"
          "config-file-value" = "/fluent-bit/configs/extra.conf"
        }
      }
      environment = [
        { name = "AWS_REGION",     value = var.aws_region },
        { name = "S3_BUCKET_NAME", value = aws_s3_bucket.verify_logs.id },
      ]
      
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
        }
      }
    }
  ])

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}
