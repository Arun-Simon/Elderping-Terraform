variable "project"                    { type = string }
variable "kms_key_arn"                { type = string }
variable "private_app_subnet_ids"     { type = list(string) }
variable "lambda_sg_id"               { type = string }
variable "reminders_topic_arn"        { type = string }
variable "caregiver_alerts_topic_arn" { type = string }
variable "db_reminder_secret_arn"     { type = string }
variable "tags"                       { type = map(string); default = {} }