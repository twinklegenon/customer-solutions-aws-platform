##################################
# Interfaces
##################################

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "region" {
  type        = string
  description = "AWS region, used for the container log configuration"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the load balancer"
}

variable "app_subnet_ids" {
  type        = list(string)
  description = "Private app subnet IDs for the ECS tasks"
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group for the load balancer"
}

variable "app_security_group_id" {
  type        = string
  description = "Security group for the ECS tasks"
}

variable "task_execution_role_arn" {
  type        = string
  description = "ECS task execution role ARN"
}

variable "task_role_arn" {
  type        = string
  description = "ECS task role ARN"
}

variable "app_port" {
  type        = number
  description = "Port the application container listens on"
  default     = 8080
}

variable "certificate_arn" {
  type        = string
  description = "Issued ACM certificate for the HTTPS listener"
}

variable "image_tag" {
  type        = string
  description = "Tag of the application image in the ECR repository"
  default     = "latest"
}

variable "health_check_path" {
  type        = string
  description = "Path the load balancer calls to check a task"
  default     = "/"
}

variable "task_cpu" {
  type        = number
  description = "Fargate task CPU units"
  default     = 256
}

variable "task_memory" {
  type        = number
  description = "Fargate task memory in MiB"
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "Number of tasks, spread across the AZs"
  default     = 2
}

variable "alb_deletion_protection" {
  type        = bool
  description = "Block deletion of the load balancer (false only for dev)"
  default     = true
}

variable "image_repository_name" {
  type        = string
  description = "Name of the existing ECR repository that holds the application image"
}

variable "log_retention_days" {
  type        = number
  description = "Retention in days for the application log group"
  default     = 30
}

variable "task_execution_role_name" {
  type        = string
  description = "Name of the ECS task execution role, so it can read the database secret"
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager secret that holds the database credentials"
}

variable "secrets_kms_key_arn" {
  type        = string
  description = "KMS key that encrypts the database secret"
}

variable "container_environment" {
  type        = map(string)
  description = "Environment variables for the application container"
  default     = {}
}

variable "container_secrets" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
  description = "Secrets Manager values injected into the container as environment variables"
  default     = []
}

variable "alb_logs_force_destroy" {
  type        = bool
  description = "Delete the access log bucket even when it holds logs"
  default     = false
}
