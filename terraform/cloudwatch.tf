resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ecs/${var.project_name}/app"
  retention_in_days = var.app_log_retention_days

  tags = {
    Name    = "/aws/ecs/${var.project_name}/app"
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "log_router" {
  name              = "/aws/ecs/${var.project_name}/log-router"
  retention_in_days = var.log_router_retention_days

  tags = {
    Name    = "/aws/ecs/${var.project_name}/log-router"
    Project = var.project_name
  }
}
