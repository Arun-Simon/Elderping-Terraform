output "event_rule_arn" { value = aws_cloudwatch_event_rule.reminder_schedule.arn }
output "event_rule_name" { value = aws_cloudwatch_event_rule.reminder_schedule.name }
output "dlq_arn" { value = aws_sqs_queue.reminder_dlq.arn }
output "dlq_url" { value = aws_sqs_queue.reminder_dlq.id }