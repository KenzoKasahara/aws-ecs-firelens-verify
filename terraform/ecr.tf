resource "aws_ecr_repository" "log_router" {
  name                 = "${var.project_name}-log-router"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name    = "${var.project_name}-log-router"
    Project = var.project_name
  }
}
