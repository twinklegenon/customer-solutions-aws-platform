##################################
# Interfaces
##################################

output "cloudfront_domain_name" {
  description = "CloudFront domain name (d....cloudfront.net)"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.cdn.id
}

output "app_url" {
  description = "URL users visit"
  value       = "https://${var.app_domain}"
}
