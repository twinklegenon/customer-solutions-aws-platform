##################################
# Interfaces
##################################

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "zone_id" {
  type        = string
  description = "Route 53 hosted zone ID of the domain"
}

variable "app_domain" {
  type        = string
  description = "Domain users visit, served by CloudFront (for example app.example.com)"
}

variable "origin_domain" {
  type        = string
  description = "Domain CloudFront uses to reach the load balancer (matches the load balancer certificate)"
}

variable "cloudfront_certificate_arn" {
  type        = string
  description = "Issued ACM certificate in us-east-1 for the app domain"
}

variable "alb_dns_name" {
  type        = string
  description = "Load balancer DNS name"
}

variable "alb_zone_id" {
  type        = string
  description = "Load balancer hosted zone ID, for the Route 53 alias"
}

variable "static_bucket_name" {
  type        = string
  description = "Static content bucket name"
}

variable "static_bucket_arn" {
  type        = string
  description = "Static content bucket ARN"
}

variable "static_bucket_regional_domain_name" {
  type        = string
  description = "Static content bucket regional domain name, used as the CloudFront origin"
}

variable "price_class" {
  type        = string
  description = "CloudFront price class (PriceClass_200 covers North America, Europe and Asia)"
  default     = "PriceClass_200"
}

variable "rate_limit" {
  type        = number
  description = "Maximum requests from one IP address in 5 minutes before WAF blocks it"
  default     = 2000
}
