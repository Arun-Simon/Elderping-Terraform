locals {
  databases = ["users_db", "health_db", "reminder_db", "alert_db"]
}

resource "aws_secretsmanager_secret" "rds_master" {
  name                    = "${var.project}/rds/master"
  description             = "RDS master credentials"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge(var.tags, { Name = "${var.project}-rds-master-secret" })
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id     = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({ username = var.db_username, password = var.db_password })
}

resource "aws_secretsmanager_secret" "jwt" {
  name                    = "${var.project}/app/jwt-secret"
  description             = "JWT signing secret"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge(var.tags, { Name = "${var.project}-jwt-secret" })
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({ jwt_secret = var.jwt_secret })
}

resource "aws_secretsmanager_secret" "smtp" {
  name                    = "${var.project}/app/smtp"
  description             = "SMTP credentials"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge(var.tags, { Name = "${var.project}-smtp-secret" })
}

resource "aws_secretsmanager_secret_version" "smtp" {
  secret_id = aws_secretsmanager_secret.smtp.id
  secret_string = jsonencode({
    smtp_host     = var.smtp_host
    smtp_port     = var.smtp_port
    smtp_username = var.smtp_username
    smtp_password = var.smtp_password
  })
}

resource "aws_secretsmanager_secret" "db_conn" {
  for_each                = toset(local.databases)
  name                    = "${var.project}/db/${each.key}/connection"
  description             = "Connection info for ${each.key}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = merge(var.tags, { Name = "${var.project}-${each.key}-conn" })
}

resource "aws_secretsmanager_secret_version" "db_conn" {
  for_each  = toset(local.databases)
  secret_id = aws_secretsmanager_secret.db_conn[each.key].id
  secret_string = jsonencode({
    host     = var.rds_endpoint
    port     = 5432
    dbname   = each.key
    username = var.db_username
    password = var.db_password
  })
}