resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.db_subnet_ids
  tags       = merge(var.tags, { Name = "${var.project}-db-subnet-group" })
}

resource "aws_db_parameter_group" "postgres15" {
  name   = "${var.project}-pg15-params"
  family = "postgres15"

  parameter { 
    name = "log_connections"           
    value = "1" 
    }
  parameter { 
    name = "log_disconnections"
    value = "1" }
  parameter { 
    name = "log_statement"           
    value = "ddl" 
    }
  parameter { 
    name = "log_min_duration_statement" 
    value = "1000" 
    }

  tags = merge(var.tags,{
     Name = "${var.project}-pg15-params" 
     })
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project}-rds-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project}-postgres"
  engine                 = "postgres"
  engine_version         = "15.7"
  instance_class         = var.instance_class
  parameter_group_name   = aws_db_parameter_group.postgres15.name
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  kms_key_id             = var.kms_key_arn
  db_name                = "postgres"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = true
  backup_retention_period           = var.backup_retention_period
  backup_window                     = "03:00-04:00"
  maintenance_window                = "Mon:04:00-Mon:05:00"
  skip_final_snapshot               = false
  final_snapshot_identifier         = "${var.project}-final-snapshot"
  copy_tags_to_snapshot             = true
  deletion_protection               = var.deletion_protection
  monitoring_interval               = 60
  monitoring_role_arn               = aws_iam_role.rds_enhanced_monitoring.arn
  performance_insights_enabled      = true
  performance_insights_kms_key_id   = var.kms_key_arn
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports   = ["postgresql", "upgrade"]

  tags = merge(var.tags, { Name = "${var.project}-postgres" })
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = var.alarm_sns_arns
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.id }
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.project}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240
  alarm_actions       = var.alarm_sns_arns
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.id }
  tags                = var.tags
}