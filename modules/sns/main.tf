data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "reminders" {
  name              = "${var.project}-reminders"
  display_name      = "ElderPing Medication Reminders"
  kms_master_key_id = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${var.project}-reminders" })
}

resource "aws_sns_topic" "caregiver_alerts" {
  name              = "${var.project}-caregiver-alerts"
  display_name      = "ElderPing Caregiver Alerts"
  kms_master_key_id = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${var.project}-caregiver-alerts" })
}

resource "aws_sns_topic" "infra_alarms" {
  name              = "${var.project}-infra-alarms"
  display_name      = "ElderPing Infrastructure Alarms"
  kms_master_key_id = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${var.project}-infra-alarms" })
}

resource "aws_sns_topic_subscription" "infra_email" {
  for_each  = toset(var.alarm_email_addresses)
  topic_arn = aws_sns_topic.infra_alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_policy" "reminders" {
  arn = aws_sns_topic.reminders.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowLambdaPublish"
      Effect    = "Allow"
      Principal = { AWS = var.lambda_role_arn != "" ? var.lambda_role_arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.reminders.arn
    }]
  })
}