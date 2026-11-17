##################################
# Interfaces
##################################

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block of the DR VPC (must not overlap the primary VPC)"
}

variable "subnets" {
  type        = map(string)
  description = "Private data subnet CIDRs, keyed by availability zone name in the DR region (at least two)"
}

variable "source_db_arn" {
  type        = string
  description = "ARN of the primary database the replica copies"
}

variable "db_instance_class" {
  type        = string
  description = "Instance class of the replica"
}

variable "db_multi_az" {
  type        = bool
  description = "Create a Multi-AZ standby for the replica (false keeps the pilot light cheap)"
  default     = false
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Skip the final snapshot when the replica is destroyed (true only for dev)"
  default     = false
}

variable "db_deletion_protection" {
  type        = bool
  description = "Block deletion of the replica (false only for dev)"
  default     = true
}

variable "alarm_email" {
  type        = string
  description = "Email address that receives the replica lag alarm"
  sensitive   = true
}

variable "replica_lag_threshold_seconds" {
  type        = number
  description = "Alarm when the replica is behind the primary by more than this many seconds"
  default     = 300
}
