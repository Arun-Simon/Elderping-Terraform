variable "project"             { type = string }
variable "lambda_function_arn" { type = string }
variable "kms_key_arn"         { type = string }
variable "schedule_expression" { type = string; default = "rate(5 minutes)" }
variable "tags"                { type = map(string); default = {} }