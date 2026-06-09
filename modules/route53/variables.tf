variable "project" { type = string }
variable "domain_name" { type = string }
variable "hosted_zone_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}