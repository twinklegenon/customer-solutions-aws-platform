##################################
# Interfaces
##################################

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "region" {
  type        = string
  description = "AWS region, used to look up the S3 prefix list"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC the security groups belong to"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC, for HTTPS to the VPC endpoints"
}

variable "app_port" {
  type        = number
  description = "Port the application container listens on (HTTPS)"
  default     = 8443
}

variable "db_port" {
  type        = number
  description = "Port the database listens on (5432 for PostgreSQL)"
  default     = 5432
}

variable "alb_port" {
  type        = number
  description = "Port the load balancer listens on: 443 with a certificate, 80 without"
  default     = 443
}
