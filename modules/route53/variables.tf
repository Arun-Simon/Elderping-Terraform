variable "project" { type = string }
variable "domain_name" { type = string }
variable "hosted_zone_name" { type = string }
variable "cloudfront_domain_name" { type = string }
variable "cloudfront_hosted_zone_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}