data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "lambda" {
  name = "${var.project}-lambda-reminder-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole"; Effect = "Allow"; Principal = { Service = "lambda.amazonaws.com" } }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_custom" {
  name = "${var.project}-lambda-reminder-policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PublishSNS"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.reminders_topic_arn, var.caregiver_alerts_topic_arn]
      },
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project}/*"
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt","kms:GenerateDataKey"]
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

data "archive_file" "reminder_lambda" {
  type        = "zip"
  output_path = "${path.module}/reminder_lambda.zip"
  source {
    content  = file("${path.module}/lambda_src/index.py")
    filename = "index.py"
  }
}

resource "aws_cloudwatch_log_group" "lambda_reminder" {
  name              = "/aws/lambda/${var.project}-reminder-scheduler"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn
  tags              = var.tags
}

resource "aws_lambda_function" "reminder_scheduler" {
  function_name    = "${var.project}-reminder-scheduler"
  description      = "Checks upcoming reminders and sends SNS notifications"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.reminder_lambda.output_path
  source_code_hash = data.archive_file.reminder_lambda.output_base64sha256

  environment {
    variables = {
      REMINDERS_TOPIC_ARN        = var.reminders_topic_arn
      CAREGIVER_ALERTS_TOPIC_ARN = var.caregiver_alerts_topic_arn
      DB_SECRET_ARN              = var.db_reminder_secret_arn
      AWS_REGION_NAME            = data.aws_region.current.name
      PROJECT                    = var.project
    }
  }

  vpc_config {
    subnet_ids         = var.private_app_subnet_ids
    security_group_ids = [var.lambda_sg_id]
  }

  kms_key_arn = var.kms_key_arn

  tracing_config { mode = "Active" }

  depends_on = [aws_cloudwatch_log_group.lambda_reminder, aws_iam_role_policy_attachment.lambda_basic]
  tags       = merge(var.tags, { Name = "${var.project}-reminder-scheduler" })
}