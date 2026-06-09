variable "project"               { type = string }
variable "kms_key_arn"           { type = string }
variable "lambda_role_arn"       { 
    type = string 
    default = "" 
    }
variable "alarm_email_addresses" { 
    type = list(string) 
    default = [] 
    }
variable "tags"                  { 
    type = map(string) 
    default = {} 
    }