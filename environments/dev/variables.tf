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
