##################################
# Interfaces
##################################

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "data_subnet_ids" {
  type        = list(string)
  description = "Private data subnet IDs, at least two AZs"
}

variable "kms_key_arns" {
  type        = map(string)
  description = "KMS key ARNs keyed by service (rds, redis, s3, secrets)"
}

variable "rds_security_group_id" {
  type        = string
  description = "Security group for the database"
}

variable "redis_security_group_id" {
  type        = string
  description = "Security group for the Redis cache"
}

# --- RDS (PostgreSQL) -------------------------------------------------------

variable "db_engine_version" {
  type        = string
  description = "PostgreSQL major version"
  default     = "17"
}

variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "RDS storage in GiB"
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Name of the initial database"
  default     = "app"
}

variable "db_username" {
  type        = string
  description = "Master username (the password is generated and stored in Secrets Manager)"
  default     = "dbadmin"
}

variable "db_multi_az" {
  type        = bool
  description = "Create a Multi-AZ standby"
  default     = true
}

variable "db_backup_retention_days" {
  type        = number
  description = "Days to keep automated backups (must be 1 or more for a cross-region read replica)"
  default     = 7
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Skip the final snapshot when the database is destroyed (true only for dev)"
  default     = false
}

variable "db_deletion_protection" {
  type        = bool
  description = "Block deletion of the database (false only for dev)"
  default     = true
}

# --- Redis ------------------------------------------------------------------

variable "redis_engine_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.1"
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache node type"
  default     = "cache.t4g.micro"
}

variable "redis_nodes" {
  type        = number
  description = "Number of cache nodes (2 or more enables automatic failover)"
  default     = 1
}

# --- S3 static content ------------------------------------------------------

variable "s3_force_destroy" {
  type        = bool
  description = "Delete the static bucket even when it holds objects (true only for dev)"
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "Retention in days for the database log group"
  default     = 30
}
