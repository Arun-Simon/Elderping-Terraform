data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "main" {}

locals {
  buckets = {
    backups   = "${var.project}-backups-${data.aws_caller_identity.current.account_id}"
    reports   = "${var.project}-reports-${data.aws_caller_identity.current.account_id}"
    documents = "${var.project}-documents-${data.aws_caller_identity.current.account_id}"
    logs      = "${var.project}-app-logs-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket" "app" {
  for_each      = local.buckets
  bucket        = each.value
  force_destroy = false
  tags          = merge(var.tags, { Name = each.value, Purpose = each.key })
}

resource "aws_s3_bucket_versioning" "app" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.app[each.key].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.app[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  for_each                = local.buckets
  bucket                  = aws_s3_bucket.app[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "app" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.app[each.key].id
  rule {
    id     = "archive"
    status = "Enabled"
    transition { 
        days = 30
        storage_class = "STANDARD_IA" 
        }
    transition { 
        days = 90
        storage_class = "GLACIER" 
        }
    expiration { 
        days = 2555 
        }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = false
  tags          = merge(var.tags, { Name = "${var.project}-alb-logs" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = data.aws_elb_service_account.main.arn }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs.arn}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-alb-logs"
    status = "Enabled"
    expiration { days = 90 }
  }
}