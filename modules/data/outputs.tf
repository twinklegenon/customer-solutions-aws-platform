##################################
# Interfaces
##################################

output "db_address" {
  description = "Database host name"
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "Database port"
  value       = aws_db_instance.postgres.port
}

output "db_master_secret_arn" {
  description = "Secrets Manager secret that holds the database master password"
  value       = aws_secretsmanager_secret.db.arn
}

output "db_arn" {
  description = "Database ARN, used as the source of the cross-region read replica"
  value       = aws_db_instance.postgres.arn
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint address"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "static_bucket_name" {
  description = "Static content bucket name"
  value       = aws_s3_bucket.static.id
}

output "static_bucket_arn" {
  description = "Static content bucket ARN"
  value       = aws_s3_bucket.static.arn
}

output "static_bucket_regional_domain_name" {
  description = "Regional domain name, used as the CloudFront origin"
  value       = aws_s3_bucket.static.bucket_regional_domain_name
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.postgres.db_name
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.postgres.identifier
}

output "redis_replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = aws_elasticache_replication_group.redis.replication_group_id
}
