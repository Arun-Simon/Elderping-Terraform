variable "project" { type = string }
variable "vpc_id" { type = string }
variable "private_app_subnet_cidrs" { type = list(string) }
variable "private_db_subnet_cidrs" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}