##################################
# Interfaces
##################################

variable "domain_name" {
  type        = string
  description = "Registered domain with a public Route 53 hosted zone, for example example.com"
}

variable "app_subdomain" {
  type        = string
  description = "Subdomain users visit (served by CloudFront)"
  default     = "app"
}

variable "origin_subdomain" {
  type        = string
  description = "Subdomain CloudFront uses to reach the load balancer (its certificate must match this name)"
  default     = "origin"
}
