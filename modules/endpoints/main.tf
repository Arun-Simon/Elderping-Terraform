data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name

  interface_endpoints = {
    secretsmanager = "com.amazonaws.${local.region}.secretsmanager"
    ssm            = "com.amazonaws.${local.region}.ssm"
    ec2messages    = "com.amazonaws.${local.region}.ec2messages"
    ssmmessages    = "com.amazonaws.${local.region}.ssmmessages"
    logs           = "com.amazonaws.${local.region}.logs"
    monitoring     = "com.amazonaws.${local.region}.monitoring"
    kms            = "com.amazonaws.${local.region}.kms"
    lambda         = "com.amazonaws.${local.region}.lambda"
    sns            = "com.amazonaws.${local.region}.sns"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids
  tags              = merge(var.tags, { Name = "${var.project}-vpce-s3" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_app_subnet_ids
  security_group_ids  = [var.vpc_endpoint_sg_id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.project}-vpce-${each.key}" })
}