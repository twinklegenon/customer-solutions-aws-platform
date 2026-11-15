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


variable "ecr_force_delete" {
  type        = bool
  description = "Delete the ECR repository even when it holds images"
  default     = false
}
