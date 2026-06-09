terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  backend "s3" {
    bucket         = "elderping-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/elderping-main"
    dynamodb_table = "elderping-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.common_tags }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags { tags = local.common_tags }
}

locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
  }
}

module "kms" {
  source                  = "../../modules/kms"
  project                 = var.project
  deletion_window_in_days = 30
  tags                    = local.common_tags
}

module "backend" {
  source            = "../../modules/backend"
  project           = var.project
  state_bucket_name = "${var.project}-terraform-state"
  lock_table_name   = "${var.project}-terraform-locks"
  kms_key_arn       = module.kms.main_key_arn
  tags              = local.common_tags
}

module "vpc" {
  source                    = "../../modules/vpc"
  project                   = var.project
  vpc_cidr                  = var.vpc_cidr
  public_subnet_a_cidr      = var.public_subnet_a_cidr
  public_subnet_b_cidr      = var.public_subnet_b_cidr
  private_app_subnet_a_cidr = var.private_app_subnet_a_cidr
  private_app_subnet_b_cidr = var.private_app_subnet_b_cidr
  private_db_subnet_a_cidr  = var.private_db_subnet_a_cidr
  private_db_subnet_b_cidr  = var.private_db_subnet_b_cidr
  tags                      = local.common_tags
}

module "security_groups" {
  source                   = "../../modules/security-groups"
  project                  = var.project
  vpc_id                   = module.vpc.vpc_id
  private_app_subnet_cidrs = [var.private_app_subnet_a_cidr, var.private_app_subnet_b_cidr]
  private_db_subnet_cidrs  = [var.private_db_subnet_a_cidr, var.private_db_subnet_b_cidr]
  tags                     = local.common_tags
}

data "aws_route_table" "private_app_a" { subnet_id = module.vpc.private_app_subnet_a_id }
data "aws_route_table" "private_app_b" { subnet_id = module.vpc.private_app_subnet_b_id }
data "aws_route_table" "private_db" { subnet_id = module.vpc.private_db_subnet_a_id }

module "endpoints" {
  source                 = "../../modules/endpoints"
  project                = var.project
  vpc_id                 = module.vpc.vpc_id
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  private_route_table_ids = [
    data.aws_route_table.private_app_a.id,
    data.aws_route_table.private_app_b.id,
    data.aws_route_table.private_db.id
  ]
  vpc_endpoint_sg_id = module.security_groups.vpc_endpoints_sg_id
  tags               = local.common_tags
}

module "s3" {
  source      = "../../modules/s3"
  project     = var.project
  kms_key_arn = module.kms.main_key_arn
  tags        = local.common_tags
}

module "sns" {
  source                = "../../modules/sns"
  project               = var.project
  kms_key_arn           = module.kms.main_key_arn
  alarm_email_addresses = var.alarm_email_addresses
  tags                  = local.common_tags
}

module "rds" {
  source                  = "../../modules/rds"
  project                 = var.project
  db_subnet_ids           = module.vpc.private_db_subnet_ids
  rds_sg_id               = module.security_groups.rds_sg_id
  kms_key_arn             = module.kms.main_key_arn
  db_username             = var.db_username
  db_password             = var.db_password
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = true
  alarm_sns_arns          = [module.sns.infra_alarms_topic_arn]
  tags                    = local.common_tags
}

module "secrets_manager" {
  source                  = "../../modules/secrets-manager"
  project                 = var.project
  kms_key_arn             = module.kms.main_key_arn
  db_username             = var.db_username
  db_password             = var.db_password
  jwt_secret              = var.jwt_secret
  smtp_host               = var.smtp_host
  smtp_port               = var.smtp_port
  smtp_username           = var.smtp_username
  smtp_password           = var.smtp_password
  rds_endpoint            = module.rds.address
  recovery_window_in_days = 30
  tags                    = local.common_tags
  depends_on              = [module.rds]
}

module "waf" {
  source         = "../../modules/waf"
  providers      = { aws = aws.us_east_1 }
  project        = var.project
  log_bucket_arn = module.s3.bucket_arns["logs"]
  tags           = local.common_tags
}

module "alb" {
  source                     = "../../modules/alb"
  project                    = var.project
  vpc_id                     = module.vpc.vpc_id
  alb_sg_id                  = module.security_groups.alb_sg_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  acm_certificate_arn        = module.route53.acm_certificate_arn
  access_log_bucket          = module.s3.alb_logs_bucket_name
  enable_deletion_protection = true
  tags                       = local.common_tags
}

module "cloudfront" {
  source              = "../../modules/cloudfront"
  project             = var.project
  domain_name         = var.domain_name
  alb_dns_name        = module.alb.alb_dns_name
  acm_certificate_arn = module.route53.acm_certificate_arn
  waf_web_acl_arn     = module.waf.web_acl_arn
  log_bucket_domain   = "${module.s3.logs_bucket_name}.s3.amazonaws.com"
  tags                = local.common_tags
  depends_on          = [module.alb, module.waf]
}

module "route53" {
  source                    = "../../modules/route53"
  providers                 = { aws.us_east_1 = aws.us_east_1 }
  project                   = var.project
  domain_name               = var.domain_name
  hosted_zone_name          = var.hosted_zone_name
  cloudfront_domain_name    = module.cloudfront.domain_name
  cloudfront_hosted_zone_id = module.cloudfront.hosted_zone_id
  tags                      = local.common_tags
  depends_on                = [module.cloudfront]
}

module "ec2" {
  source                 = "../../modules/ec2"
  project                = var.project
  ami_id                 = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  ec2_sg_id              = module.security_groups.ec2_sg_id
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  kms_key_arn            = module.kms.main_key_arn
  alb_target_group_arn   = module.alb.target_group_arn
  rds_endpoint           = module.rds.address
  rds_master_secret_arn  = module.secrets_manager.rds_master_secret_arn
  jwt_secret_arn         = module.secrets_manager.jwt_secret_arn
  smtp_secret_arn        = module.secrets_manager.smtp_secret_arn
  app_s3_bucket_name     = module.s3.backups_bucket_name
  ecr_registry           = var.ecr_registry
  image_tag              = var.image_tag
  asg_min                = var.asg_min
  asg_desired            = var.asg_desired
  asg_max                = var.asg_max
  tags                   = local.common_tags
}

module "lambda" {
  source                     = "../../modules/lambda"
  project                    = var.project
  kms_key_arn                = module.kms.main_key_arn
  private_app_subnet_ids     = module.vpc.private_app_subnet_ids
  lambda_sg_id               = module.security_groups.lambda_sg_id
  reminders_topic_arn        = module.sns.reminders_topic_arn
  caregiver_alerts_topic_arn = module.sns.caregiver_alerts_topic_arn
  db_reminder_secret_arn     = module.secrets_manager.db_conn_secret_arns["reminder_db"]
  tags                       = local.common_tags
}

module "eventbridge" {
  source              = "../../modules/eventbridge"
  project             = var.project
  lambda_function_arn = module.lambda.function_arn
  kms_key_arn         = module.kms.main_key_arn
  tags                = local.common_tags
}

module "cloudwatch" {
  source                  = "../../modules/cloudwatch"
  project                 = var.project
  aws_region              = var.aws_region
  kms_key_arn             = module.kms.main_key_arn
  asg_name                = module.ec2.asg_name
  alb_arn_suffix          = module.alb.alb_arn
  target_group_arn_suffix = module.alb.target_group_arn
  rds_instance_id         = module.rds.instance_id
  alarm_sns_arns          = [module.sns.infra_alarms_topic_arn]
  log_retention_days      = var.log_retention_days
  tags                    = local.common_tags
}

module "cloudtrail" {
  source                 = "../../modules/cloudtrail"
  project                = var.project
  cloudtrail_kms_key_arn = module.kms.cloudtrail_key_arn
  log_retention_days     = var.log_retention_days
  tags                   = local.common_tags
}