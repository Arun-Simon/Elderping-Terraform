resource "aws_cloudwatch_event_rule" "reminder_schedule" {
  name                = "${var.project}-reminder-schedule"
  description         = "Trigger reminder Lambda every 5 minutes"
  schedule_expression = var.schedule_expression
  state               = "ENABLED"
  tags                = merge(var.tags, { Name = "${var.project}-reminder-schedule" })
}

resource "aws_cloudwatch_event_target" "reminder_lambda" {
  rule      = aws_cloudwatch_event_rule.reminder_schedule.name
  target_id = "${var.project}-reminder-lambda-target"
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reminder_schedule.arn
}

resource "aws_sqs_queue" "reminder_dlq" {
  name                      = "${var.project}-reminder-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_key_arn
  tags                      = merge(var.tags, { Name = "${var.project}-reminder-dlq" })
}