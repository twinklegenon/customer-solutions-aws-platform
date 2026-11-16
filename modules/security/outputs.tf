##################################
# Interfaces
##################################

output "kms_key_arns" {
  description = "KMS key ARNs, keyed by service (rds, redis, s3, secrets, sns)"
  value       = { for name, key in aws_kms_key.service_key : name => key.arn }
}

output "alb_security_group_id" {
  description = "Security group for the load balancer"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group for the application tasks"
  value       = aws_security_group.app.id
}

output "rds_security_group_id" {
  description = "Security group for the database"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "Security group for the Redis cache"
  value       = aws_security_group.redis.id
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_execution_role_name" {
  description = "ECS task execution role name"
  value       = aws_iam_role.ecs_task_execution.name
}
