data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ 
        Action = "sts:AssumeRole" 
        Effect = "Allow"
        Principal = { Service = "ec2.amazonaws.com" } 
        }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_custom" {
  name = "${var.project}-ec2-custom-policy"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerRead"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:${var.project}/*"
      },
      {
        Sid      = "KMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt","kms:GenerateDataKey"]
        Resource = [var.kms_key_arn]
      },
      {
        Sid      = "S3Access"
        Effect   = "Allow"
        Action   = ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"]
        Resource = ["arn:aws:s3:::${var.app_s3_bucket_name}","arn:aws:s3:::${var.app_s3_bucket_name}/*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2.name
}

locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    project               = var.project
    region                = local.region
    rds_endpoint          = var.rds_endpoint
    rds_master_secret_arn = var.rds_master_secret_arn
    jwt_secret_arn        = var.jwt_secret_arn
    smtp_secret_arn       = var.smtp_secret_arn
    ecr_registry          = var.ecr_registry
    image_tag             = var.image_tag
    s3_bucket             = var.app_s3_bucket_name
    log_group             = "/aws/ec2/${var.project}"
  }))
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile { arn = aws_iam_instance_profile.ec2.arn }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.ec2_sg_id]
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  user_data = local.user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring { enabled = true }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.project}-app" })
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.project}-asg"
  min_size                  = var.asg_min
  desired_capacity          = var.asg_desired
  max_size                  = var.asg_max
  vpc_zone_identifier       = var.private_app_subnet_ids
  target_group_arns         = [var.alb_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences { min_healthy_percentage = 50 }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.project}-app" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification { predefined_metric_type = "ASGAverageCPUUtilization" }
    target_value = 70.0
  }
}