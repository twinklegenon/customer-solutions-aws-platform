##################################
# Interfaces
##################################

output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = data.aws_route53_zone.zone.zone_id
}

output "app_domain" {
  description = "Domain users visit, served by CloudFront"
  value       = local.app_domain
}

output "origin_domain" {
  description = "Domain CloudFront uses to reach the load balancer"
  value       = local.origin_domain
}

output "alb_certificate_arn" {
  description = "Issued certificate for the load balancer HTTPS listener"
  value       = aws_acm_certificate_validation.alb.certificate_arn
}

output "cloudfront_certificate_arn" {
  description = "Issued certificate (us-east-1) for the CloudFront distribution"
  value       = aws_acm_certificate_validation.cloudfront.certificate_arn
}
