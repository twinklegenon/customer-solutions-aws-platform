##################################
# Interfaces
##################################

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "region" {
  type        = string
  description = "AWS region the VPC is created in"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "subnets" {
  type = map(object({
    public = string
    app    = string
    data   = string
  }))
  description = "Subnet CIDRs per availability zone, keyed by AZ name (set per environment)"
}

variable "enable_flow_logs" {
  type        = bool
  description = "Send VPC flow logs to CloudWatch Logs"
  default     = true
}

variable "flow_log_retention_days" {
  type        = number
  description = "Retention in days for the flow log group"
  default     = 30
}
