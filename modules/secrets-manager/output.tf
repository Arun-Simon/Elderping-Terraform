output "rds_master_secret_arn" { value = aws_secretsmanager_secret.rds_master.arn }
output "jwt_secret_arn" { value = aws_secretsmanager_secret.jwt.arn }
output "smtp_secret_arn" { value = aws_secretsmanager_secret.smtp.arn }
output "db_conn_secret_arns" {
  value = { for k, v in aws_secretsmanager_secret.db_conn : k => v.arn }
}