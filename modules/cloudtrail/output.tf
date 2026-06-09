output "trail_arn" { value = aws_cloudtrail.main.arn }
output "cloudtrail_bucket_name" { value = aws_s3_bucket.cloudtrail.bucket }
output "cloudtrail_bucket_arn" { value = aws_s3_bucket.cloudtrail.arn }
output "cloudtrail_log_group_arn" { value = aws_cloudwatch_log_group.cloudtrail.arn }