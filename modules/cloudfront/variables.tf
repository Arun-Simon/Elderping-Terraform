variable "project"              { type = string }
variable "domain_name"          { type = string }
variable "alb_dns_name"         { type = string }
variable "acm_certificate_arn"  { type = string }
variable "waf_web_acl_arn"      { type = string }
variable "origin_verify_secret" { 
    type = string 
    sensitive = true 
    default = "changeme" 
    }
variable "log_bucket_domain"    { 
    type = string 
    default = "" 
    }
variable "tags"                 { 
    type = map(string) 
    default = {} 
    }