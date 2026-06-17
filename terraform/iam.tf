data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------------------
# タスクロール — 実行中のコンテナに CloudWatch Logs (app ロググループ) および
# S3 (検証用ログ送信先) への書き込み権限を付与する
# ---------------------------------------------------------------------------
resource "aws_iam_role" "task" {
  name               = "${var.project_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = {
    Name    = "${var.project_name}-task-role"
    Project = var.project_name
  }
}

data "aws_iam_policy_document" "task_policy" {
  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }

  statement {
    sid     = "S3PutLogs"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.verify_logs.arn}/*"]
  }
}

resource "aws_iam_policy" "task_policy" {
  name   = "${var.project_name}-task-policy"
  policy = data.aws_iam_policy_document.task_policy.json

  tags = {
    Name    = "${var.project_name}-task-policy"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "task_policy" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_policy.arn
}

# ---------------------------------------------------------------------------
# 実行ロール — ECS エージェントがイメージをプルし、log_router (Fluent Bit) の
# 起動ログを awslogs ドライバ経由で書き込む際に使用する
# ---------------------------------------------------------------------------
resource "aws_iam_role" "execution" {
  name               = "${var.project_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = {
    Name    = "${var.project_name}-execution-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_logs" {
  statement {
    sid    = "LogRouterAwslogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.log_router.arn}:*"]
  }
}

resource "aws_iam_policy" "execution_logs" {
  name   = "${var.project_name}-execution-logs-policy"
  policy = data.aws_iam_policy_document.execution_logs.json

  tags = {
    Name    = "${var.project_name}-execution-logs-policy"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "execution_logs" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution_logs.arn
}

