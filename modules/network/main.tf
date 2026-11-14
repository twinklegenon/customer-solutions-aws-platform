##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}-{az}, e.g. dev-subnet-public-1a.
locals {
  name_prefix = var.environment
}

# --- VPC ---------------------------------------------------------------

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = { Name = "${local.name_prefix}-igw" }
}

# --- Subnets (public / private app / private data) ---------------------

# One subnet per AZ in var.subnets: each.key = AZ, each.value = its CIDRs.
resource "aws_subnet" "public" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.main_vpc.id
  availability_zone       = each.key
  cidr_block              = each.value.public
  map_public_ip_on_launch = false

  tags = { Name = "${local.name_prefix}-subnet-public-${substr(each.key, -2, -1)}" }
}

resource "aws_subnet" "private_app" {
  for_each = var.subnets

  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.key
  cidr_block        = each.value.app

  tags = { Name = "${local.name_prefix}-subnet-private-app-${substr(each.key, -2, -1)}" }
}

resource "aws_subnet" "private_data" {
  for_each = var.subnets

  vpc_id            = aws_vpc.main_vpc.id
  availability_zone = each.key
  cidr_block        = each.value.data

  tags = { Name = "${local.name_prefix}-subnet-private-data-${substr(each.key, -2, -1)}" }
}

# --- Route tables ------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main_vpc.id

  tags = { Name = "${local.name_prefix}-rtb-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# App tier has no route to the internet; AWS services are reached through VPC endpoints.
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main_vpc.id

  tags = { Name = "${local.name_prefix}-rtb-private-app" }
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app.id
}

# Data tier has no route to the internet.
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main_vpc.id

  tags = { Name = "${local.name_prefix}-rtb-private-data" }
}

resource "aws_route_table_association" "private_data" {
  for_each = aws_subnet.private_data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_data.id
}

# --- VPC endpoints -----------------------------------------------------

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main_vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_app.id, aws_route_table.private_data.id]

  tags = { Name = "${local.name_prefix}-vpce-s3" }
}

resource "aws_security_group" "endpoints" {
  name        = "${local.name_prefix}-sg-vpce"
  description = "Allow HTTPS from inside the VPC to interface endpoints"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(["ecr.api", "ecr.dkr", "logs", "secretsmanager"])

  vpc_id              = aws_vpc.main_vpc.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for subnet in aws_subnet.private_app : subnet.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${local.name_prefix}-vpce-${replace(each.key, ".", "-")}" }
}

# --- Flow logs ---------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/${local.name_prefix}/vpc/flow-logs"
  retention_in_days = var.flow_log_retention_days
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_write" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow[0].arn}:*"]
  }
}

resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${local.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

resource "aws_iam_role_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "${local.name_prefix}-vpc-flow-logs-write"
  role   = aws_iam_role.flow[0].id
  policy = data.aws_iam_policy_document.flow_write[0].json
}

resource "aws_flow_log" "vpc_flow" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.main_vpc.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow[0].arn
  log_destination = aws_cloudwatch_log_group.flow[0].arn

  tags = { Name = "${local.name_prefix}-vpc-flow-log" }
}
