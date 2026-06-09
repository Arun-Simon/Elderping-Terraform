output "bucket_names" { value = { for k, v in aws_s3_bucket.app : k => v.bucket } }
output "bucket_arns" { value = { for k, v in aws_s3_bucket.app : k => v.arn } }
output "backups_bucket_name" { value = aws_s3_bucket.app["backups"].bucket }
output "reports_bucket_name" { value = aws_s3_bucket.app["reports"].bucket }
output "documents_bucket_name" { value = aws_s3_bucket.app["documents"].bucket }
output "logs_bucket_name" { value = aws_s3_bucket.app["logs"].bucket }
output "alb_logs_bucket_name" { value = aws_s3_bucket.alb_logs.bucket }
output "alb_logs_bucket_arn" { value = aws_s3_bucket.alb_logs.arn }