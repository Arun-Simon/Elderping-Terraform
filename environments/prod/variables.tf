variable "project" {
  type    = string
  default = "elderping"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "owner_email" {
  type    = string
  default = "ops@elderping.com"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "private_app_subnet_a_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

variable "private_app_subnet_b_cidr" {
  type    = string
  default = "10.0.12.0/24"
}

variable "private_db_subnet_a_cidr" {
  type    = string
  default = "10.0.21.0/24"
}

variable "private_db_subnet_b_cidr" {
  type    = string
  default = "10.0.22.0/24"
}

variable "domain_name" {
  type = string
}

variable "hosted_zone_name" {
  type = string
}

variable "ec2_ami_id" {
  type = string
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.medium"
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

variable "ecr_registry" {
  type    = string
  default = ""
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "rds_allocated_storage" {
  type    = number
  default = 100
}

variable "rds_backup_retention_period" {
  type    = number
  default = 7
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "smtp_host" {
  type    = string
  default = ""
}

variable "smtp_port" {
  type    = string
  default = "587"
}

variable "smtp_username" {
  type      = string
  default   = ""
  sensitive = true
}

variable "smtp_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "alarm_email_addresses" {
  type    = list(string)
  default = []
}

variable "log_retention_days" {
  type    = number
  default = 30
}
