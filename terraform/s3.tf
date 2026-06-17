resource "aws_s3_bucket" "verify_logs" {
  bucket        = "${var.project_name}-logs-${var.s3_bucket_suffix}"
  force_destroy = true

  tags = {
    Name    = "${var.project_name}-logs-${var.s3_bucket_suffix}"
    Project = var.project_name
  }
}

resource "aws_s3_bucket_public_access_block" "verify_logs" {
  bucket = aws_s3_bucket.verify_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
