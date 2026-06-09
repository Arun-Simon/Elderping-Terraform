output "main_key_arn"       { value = aws_kms_key.main.arn }
output "main_key_id"        { value = aws_kms_key.main.key_id }
output "cloudtrail_key_arn" { value = aws_kms_key.cloudtrail.arn }
output "cloudtrail_key_id"  { value = aws_kms_key.cloudtrail.key_id }