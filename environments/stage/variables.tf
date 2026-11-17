variable "project" {
  type        = string
  description = "Project name used for naming and tagging"
  default     = "customer-solutions-platform"
}


variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be dev, stage or prod."
  }
}


variable "owner" {
  type        = string
  description = "Owning team alias"
  default     = "devops"
}


variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}


variable "cost_center" {
  type        = string
  description = "Cost center for show-back/charge-back"
}


variable "region" {
  type        = string
  description = "AWS region for this environment"
}


variable "subnets" {
  type = map(object({
    public = string
    app    = string
    data   = string
  }))
  description = "Subnet CIDRs per availability zone, keyed by AZ name"
}


variable "db_skip_final_snapshot" {
  type        = bool
  description = "Skip the final database snapshot on destroy"
  default     = false
}


variable "db_deletion_protection" {
  type        = bool
  description = "Block deletion of the database"
  default     = true
}


variable "s3_force_destroy" {
  type        = bool
  description = "Delete the static bucket even when it holds objects"
  default     = false
}


variable "db_instance_class" {
  type        = string
  description = "RDS instance class"
}


variable "db_allocated_storage" {
  type        = number
  description = "RDS storage in GiB"
}


variable "db_multi_az" {
  type        = bool
  description = "Create a Multi-AZ standby for the database"
}


variable "domain_name" {
  type        = string
  description = "Registered domain with a public Route 53 hosted zone"
}


variable "alb_deletion_protection" {
  type        = bool
  description = "Block deletion of the load balancer"
  default     = true
}


variable "app_image_repository" {
  type        = string
  description = "Name of the ECR repository (created manually) that holds the application image"
}


variable "app_image_tag" {
  type        = string
  description = "Version tag of the application image in ECR that the ECS service runs"
}

variable "alarm_email" {
  type        = string
  description = "Email address for alarm notifications; set through the TF_VAR_alarm_email CI/CD variable, not in the repo"
  sensitive   = true
}

variable "enable_dr" {
  type        = bool
  description = "Create the cross-region read replica (disaster recovery, pilot light)"
  default     = false
}

variable "dr_region" {
  type        = string
  description = "Disaster recovery region"
  default     = "ap-southeast-2"
}

variable "dr_vpc_cidr" {
  type        = string
  description = "CIDR block of the DR VPC (must not overlap the primary VPC)"
}

variable "dr_subnets" {
  type        = map(string)
  description = "Private data subnet CIDRs in the DR region, keyed by availability zone name"
}

variable "service" {
  type        = string
  description = "Service area that owns the workload (web, identity, crm, ecommerce); platform resources use shared"
}

variable "workload_owner" {
  type        = string
  description = "Owning team alias of the workload resources"
}

variable "workload_cost_center" {
  type        = string
  description = "Cost center of the workload for show-back/charge-back"
}

variable "secret_recovery_window_days" {
  type        = number
  description = "Days a deleted database secret can be recovered (0 deletes it at once)"
  default     = 7
}

variable "ecs_min_tasks" {
  type        = number
  description = "Fewest ECS tasks auto scaling keeps running"
  default     = 2
}

variable "ecs_max_tasks" {
  type        = number
  description = "Most ECS tasks auto scaling can run"
  default     = 4
}
