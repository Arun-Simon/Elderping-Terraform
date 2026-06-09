variable "project" { type = string }
variable "ami_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.medium"
}
variable "ec2_sg_id" { type = string }
variable "private_app_subnet_ids" { type = list(string) }
variable "kms_key_arn" { type = string }
variable "alb_target_group_arn" { type = string }
variable "rds_endpoint" { type = string }
variable "rds_master_secret_arn" { type = string }
variable "jwt_secret_arn" { type = string }
variable "smtp_secret_arn" { type = string }
variable "app_s3_bucket_name" { type = string }
variable "ecr_registry" {
  type    = string
  default = ""
}
variable "image_tag" {
  type    = string
  default = "latest"
}
variable "root_volume_size" {
  type    = number
  default = 30
}
variable "asg_min" {
  type    = number
  default = 1
}
variable "asg_desired" {
  type    = number
  default = 2
}
variable "asg_max" {
  type    = number
  default = 4
}
variable "tags" {
  type    = map(string)
  default = {}
}