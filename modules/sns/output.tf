output "reminders_topic_arn"        { value = aws_sns_topic.reminders.arn }
output "caregiver_alerts_topic_arn" { value = aws_sns_topic.caregiver_alerts.arn }
output "infra_alarms_topic_arn"     { value = aws_sns_topic.infra_alarms.arn }