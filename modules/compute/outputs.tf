##################################
# Interfaces
##################################

output "alb_dns_name" {
  description = "Load balancer DNS name, used as the CloudFront origin"
  value       = aws_lb.alb.dns_name
}

output "alb_zone_id" {
  description = "Load balancer hosted zone ID, for Route 53 alias records"
  value       = aws_lb.alb.zone_id
}

output "ecr_repository_url" {
  description = "ECR repository URL to push the application image to"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.cluster.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "app_log_group_name" {
  description = "CloudWatch log group of the application"
  value       = aws_cloudwatch_log_group.app.name
}
