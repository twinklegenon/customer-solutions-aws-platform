##################################
# Interfaces
##################################

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "region" {
  type        = string
  description = "AWS region of the workload, used by the dashboard widgets"
}

variable "alarm_email" {
  type        = string
  description = "Email address that receives alarm notifications"
  sensitive   = true
}

variable "sns_kms_key_arn" {
  type        = string
  description = "KMS key that encrypts the alarm topic"
}

variable "alb_arn_suffix" {
  type        = string
  description = "Load balancer ARN suffix, the CloudWatch dimension value"
}

variable "target_group_arn_suffix" {
  type        = string
  description = "Target group ARN suffix, the CloudWatch dimension value"
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "ecs_service_name" {
  type        = string
  description = "ECS service name"
}

variable "db_instance_identifier" {
  type        = string
  description = "RDS instance identifier"
}

variable "redis_replication_group_id" {
  type        = string
  description = "ElastiCache replication group ID"
}

variable "cloudfront_distribution_id" {
  type        = string
  description = "CloudFront distribution ID"
}

variable "waf_web_acl_name" {
  type        = string
  description = "Name of the CloudFront web ACL"
}

variable "cpu_threshold_percent" {
  type        = number
  description = "CPU alarm threshold for ECS, RDS and Redis"
  default     = 80
}

variable "memory_threshold_percent" {
  type        = number
  description = "Memory alarm threshold for ECS and Redis"
  default     = 80
}

variable "db_free_storage_min_gib" {
  type        = number
  description = "Alarm when database free storage drops below this many GiB"
  default     = 5
}

variable "db_connections_threshold" {
  type        = number
  description = "Alarm when database connections exceed this number"
  default     = 80
}

variable "alb_5xx_threshold" {
  type        = number
  description = "Alarm when target 5xx responses exceed this number in 5 minutes"
  default     = 5
}

variable "response_time_threshold_seconds" {
  type        = number
  description = "Alarm when average target response time exceeds this many seconds"
  default     = 1
}

variable "min_healthy_hosts" {
  type        = number
  description = "Alarm when healthy targets drop below this number"
  default     = 2
}

variable "app_log_group_name" {
  type        = string
  description = "Application log group that is scanned for ERROR lines"
}

variable "app_errors_threshold" {
  type        = number
  description = "Alarm when ERROR lines in the application log exceed this number in 5 minutes"
  default     = 5
}
