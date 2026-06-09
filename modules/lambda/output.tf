output "function_arn" { value = aws_lambda_function.reminder_scheduler.arn }
output "function_name" { value = aws_lambda_function.reminder_scheduler.function_name }
output "role_arn" { value = aws_iam_role.lambda.arn }