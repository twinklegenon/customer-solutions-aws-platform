##################################
# Environment-Specific Resources
##################################

data "aws_caller_identity" "current" {}

# --- RDS PostgreSQL (primary with Multi-AZ standby) --------------------

resource "aws_db_subnet_group" "rds" {
  name       = "${local.name_prefix}-sng-rds"
  subnet_ids = var.data_subnet_ids
}

# The password is generated at apply time (ephemeral, never stored in state) and written to the
# database and to Secrets Manager. RDS-managed passwords are not used because RDS refuses
# cross-region read replicas for them.
ephemeral "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "postgres" {
  identifier     = "${local.name_prefix}-rds"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.kms_key_arns["rds"]

  db_name             = var.db_name
  username            = var.db_username
  password_wo         = ephemeral.random_password.db.result
  password_wo_version = 1

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false

  backup_retention_period = var.db_backup_retention_days
  skip_final_snapshot     = var.db_skip_final_snapshot
  deletion_protection     = var.db_deletion_protection

  enabled_cloudwatch_logs_exports = ["postgresql"]
  depends_on                      = [aws_cloudwatch_log_group.rds]
}

# The credentials the application reads. Encrypted with the secrets key.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name_prefix}-db-master"
  kms_key_id              = var.kms_key_arns["secrets"]
  recovery_window_in_days = var.secret_recovery_window_days
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string_wo = jsonencode({
    username = var.db_username
    password = ephemeral.random_password.db.result
  })
  secret_string_wo_version = 1
}

# Created here (not by RDS) so the retention is set and destroy removes it.
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${local.name_prefix}-rds/postgresql"
  retention_in_days = var.log_retention_days
}

# --- Redis cache -------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-sng-redis"
  subnet_ids = var.data_subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "${local.name_prefix} Redis cache"

  engine         = "redis"
  engine_version = var.redis_engine_version
  node_type      = var.redis_node_type
  port           = 6379

  num_cache_clusters         = var.redis_nodes
  automatic_failover_enabled = var.redis_nodes > 1

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_security_group_id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arns["redis"]
  transit_encryption_enabled = true
}

# --- S3 bucket for static content --------------------------------------

resource "aws_s3_bucket" "static" {
  bucket        = "${local.name_prefix}-s3-static-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.s3_force_destroy
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arns["s3"]
    }
  }
}
