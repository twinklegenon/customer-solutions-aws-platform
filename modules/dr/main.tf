##################################
# Environment-Specific Resources
##################################

# Pilot light: only the data tier runs in the DR region. Compute is rebuilt from the
# same modules on failover (see docs/dr.md).

data "aws_caller_identity" "current" {}

# --- Encryption keys (a replica needs a key in its own region) ---------------

resource "aws_kms_key" "rds" {
  description         = "${local.name_prefix} rds dr encryption key"
  enable_key_rotation = true

  tags = { Name = "${local.name_prefix}-kms-rds-dr" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${local.name_prefix}-kms-rds-dr"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_kms_key" "sns" {
  description         = "${local.name_prefix} sns dr encryption key"
  enable_key_rotation = true

  tags = { Name = "${local.name_prefix}-kms-sns-dr" }
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${local.name_prefix}-kms-sns-dr"
  target_key_id = aws_kms_key.sns.key_id
}

# The SNS key lets CloudWatch alarms publish to the encrypted alarm topic.
data "aws_iam_policy_document" "sns_key" {
  statement {
    sid       = "EnableAccountAccess"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudWatchAlarms"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key_policy" "sns" {
  key_id = aws_kms_key.sns.id
  policy = data.aws_iam_policy_document.sns_key.json
}

# --- Network: a small private VPC for the replica ----------------------------

resource "aws_vpc" "dr" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc-dr" }
}

resource "aws_subnet" "private_data" {
  for_each = var.subnets

  vpc_id            = aws_vpc.dr.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = { Name = "${local.name_prefix}-subnet-private-data-dr-${substr(each.key, -2, -1)}" }
}

resource "aws_db_subnet_group" "rds" {
  name       = "${local.name_prefix}-sng-rds-dr"
  subnet_ids = [for subnet in aws_subnet.private_data : subnet.id]
}

# No rules: nothing reaches the replica until the application tier is rebuilt in this VPC.
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg-rds-dr"
  description = "DR database, no inbound rules until failover"
  vpc_id      = aws_vpc.dr.id

  tags = { Name = "${local.name_prefix}-sg-rds-dr" }
}

# --- Read replica ------------------------------------------------------------

# Username, password and database name are copied from the source.
resource "aws_db_instance" "replica" {
  identifier          = "${local.name_prefix}-rds-dr"
  replicate_source_db = var.source_db_arn
  instance_class      = var.db_instance_class

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  skip_final_snapshot = var.db_skip_final_snapshot
  deletion_protection = var.db_deletion_protection
}

# --- Replica lag alarm (a CloudWatch alarm reads metrics of its own region only) ---

resource "aws_sns_topic" "alarms" {
  name              = "${local.name_prefix}-sns-alarms-dr"
  kms_master_key_id = aws_kms_key.sns.arn
}

# The subscriber must confirm the email once after the first apply.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Replica lag is the recovery point: how much recent data a regional failover could lose.
# Missing data counts as breaching, because a broken replication stops reporting the metric.
resource "aws_cloudwatch_metric_alarm" "replica_lag" {
  alarm_name          = "${local.name_prefix}-alarm-rds-replica-lag"
  alarm_description   = "DR replica is behind the primary"
  namespace           = "AWS/RDS"
  metric_name         = "ReplicaLag"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.replica_lag_threshold_seconds
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.replica.identifier
  }

  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}
