variable "project" { type = string }
variable "vpc_id" { type = string }
variable "private_app_subnet_ids" { type = list(string) }
variable "private_route_table_ids" { type = list(string) }
variable "vpc_endpoint_sg_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}