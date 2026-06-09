variable "project" { type = string }
variable "vpc_id" { type = string }
variable "alb_sg_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "acm_certificate_arn" { type = string }
variable "access_log_bucket" {
  type    = string
  default = ""
}
variable "enable_deletion_protection" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}