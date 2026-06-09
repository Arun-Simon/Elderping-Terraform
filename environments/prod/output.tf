output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "private_app_subnet_ids" { value = module.vpc.private_app_subnet_ids }
output "private_db_subnet_ids" { value = module.vpc.private_db_subnet_ids }
output "kms_main_key_arn" {
  value = module.kms.main_key_arn
}

output "rds_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}

output "rds_address" {
  value     = module.rds.address
  sensitive = true
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}
output "alb_arn" { value = module.alb.alb_arn }
output "target_group_arn" { value = module.alb.target_group_arn }
output "cloudfront_distribution_id" { value = module.cloudfront.distribution_id }
output "cloudfront_domain_name" { value = module.cloudfront.domain_name }
output "app_url" { value = "https://${var.domain_name}" }
output "acm_certificate_arn" { value = module.route53.acm_certificate_arn }
output "asg_name" { value = module.ec2.asg_name }
output "launch_template_id" { value = module.ec2.launch_template_id }
output "reminders_topic_arn" { value = module.sns.reminders_topic_arn }
output "caregiver_alerts_topic_arn" { value = module.sns.caregiver_alerts_topic_arn }
output "infra_alarms_topic_arn" { value = module.sns.infra_alarms_topic_arn }
output "lambda_function_arn" { value = module.lambda.function_arn }
output "lambda_function_name" { value = module.lambda.function_name }
output "eventbridge_rule_arn" { value = module.eventbridge.event_rule_arn }
output "s3_bucket_names" { value = module.s3.bucket_names }
output "cloudtrail_bucket_name" { value = module.cloudtrail.cloudtrail_bucket_name }
output "cloudtrail_arn" {
  value = module.cloudtrail.trail_arn
}

output "cloudwatch_log_group_names" {
  value = module.cloudwatch.log_group_names
}

output "rds_master_secret_arn" {
  value     = module.secrets_manager.rds_master_secret_arn
  sensitive = true
}