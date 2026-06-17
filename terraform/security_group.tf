# ポート 24224 のインバウンドルールは意図的に設定しない。
# FireLens の forward input はサイドカー内部通信のみで使用するため、外部に公開する必要がなく危険でもある。
resource "aws_security_group" "task" {
  name        = "${var.project_name}-task"
  description = "ECS Fargate task SG for ${var.project_name}. No port 24224 ingress by design."
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-task"
    Project = var.project_name
  }
}
