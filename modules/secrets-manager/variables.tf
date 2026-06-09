variable "project"                 { type = string }
variable "kms_key_arn"             { type = string }
variable "db_username"             { 
    type = string 
    sensitive = true 
    }
variable "db_password"             { 
    type = string 
    sensitive = true 
    }
variable "jwt_secret"              { 
    type = string 
    sensitive = true 
    }
variable "smtp_host"               { 
    type = string
    default = "" 
    }
variable "smtp_port"               { 
    type = string
    default = "587" 
    }
variable "smtp_username"           { 
    type = string
    default = ""
    sensitive = true 
    }
variable "smtp_password"           { 
    type = string 
    default = ""
    sensitive = true 
    }
variable "rds_endpoint"            { 
    type = string 
    default = "" 
    }
variable "recovery_window_in_days" { 
    type = number
    default = 30 
    }
variable "tags"                    { 
    type = map(string)
    default = {} 
    }