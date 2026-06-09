variable "project" { type = string }
variable "log_bucket_arn" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}