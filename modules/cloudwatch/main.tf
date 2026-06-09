locals {
  log_groups = {
    app        = "/aws/ec2/${var.project}"
    lambda     = "/aws/lambda/${var.project}-reminder-scheduler"
    cloudtrail = "/aws/cloudtrail/${var.project}"
  }
}

resource "aws_cloudwatch_log_group" "main" {
  for_each          = local.log_groups
  name              = each.value
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${var.project}-log-${each.key}" })
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_arns
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  alarm_name          = "${var.project}-alb-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 3
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_arns
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
  alarm_name          = "${var.project}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = var.alarm_sns_arns
  dimensions          = { AutoScalingGroupName = var.asg_name }
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_arns
  dimensions          = { FunctionName = "${var.project}-reminder-scheduler" }
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.project}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_actions       = var.alarm_sns_arns
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  tags                = var.tags
}