data "aws_availability_zones" "available" { state = "available" }

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.project}-vpc" })
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = local.az_a
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.project}-public-a", Tier = "public" })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = local.az_b
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.project}-public-b", Tier = "public" })
}

resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_a_cidr
  availability_zone = local.az_a
  tags              = merge(var.tags, { Name = "${var.project}-private-app-a", Tier = "app" })
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_b_cidr
  availability_zone = local.az_b
  tags              = merge(var.tags, { Name = "${var.project}-private-app-b", Tier = "app" })
}

resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_a_cidr
  availability_zone = local.az_a
  tags              = merge(var.tags, { Name = "${var.project}-private-db-a", Tier = "db" })
}

resource "aws_subnet" "private_db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_b_cidr
  availability_zone = local.az_b
  tags              = merge(var.tags, { Name = "${var.project}-private-db-b", Tier = "db" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.project}-igw" })
}

resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.project}-nat-eip-a" })
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.project}-nat-eip-b" })
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  tags          = merge(var.tags, { Name = "${var.project}-nat-a" })
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  tags          = merge(var.tags, { Name = "${var.project}-nat-b" })
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.tags, { Name = "${var.project}-rt-public" })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }
  tags = merge(var.tags, { Name = "${var.project}-rt-private-app-a" })
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private_app_a.id
}

resource "aws_route_table" "private_app_b" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }
  tags = merge(var.tags, { Name = "${var.project}-rt-private-app-b" })
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private_app_b.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.project}-rt-private-db" })
}

resource "aws_route_table_association" "private_db_a" {
  subnet_id      = aws_subnet.private_db_a.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_route_table_association" "private_db_b" {
  subnet_id      = aws_subnet.private_db_b.id
  route_table_id = aws_route_table.private_db.id
}