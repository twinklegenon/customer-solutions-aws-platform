##################################
# Environment-Specific Resources
##################################

# The hosted zone is created by Route 53 when the domain is registered.
data "aws_route53_zone" "zone" {
  name         = var.domain_name
  private_zone = false
}

# --- Certificate for the load balancer (origin leg: CloudFront -> ALB) ----

resource "aws_acm_certificate" "alb" {
  domain_name       = local.origin_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# --- Certificate for CloudFront (viewer leg: user -> CloudFront), us-east-1 only ---

resource "aws_acm_certificate" "cloudfront" {
  provider = aws.us_east_1

  domain_name       = local.app_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# --- DNS validation records ---------------------------------------------------

resource "aws_route53_record" "alb_validation" {
  for_each = {
    for option in aws_acm_certificate.alb.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_route53_record" "cloudfront_validation" {
  for_each = {
    for option in aws_acm_certificate.cloudfront.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  zone_id         = data.aws_route53_zone.zone.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# These wait until ACM has seen the records and issued the certificates.
resource "aws_acm_certificate_validation" "alb" {
  certificate_arn         = aws_acm_certificate.alb.arn
  validation_record_fqdns = [for record in aws_route53_record.alb_validation : record.fqdn]
}

resource "aws_acm_certificate_validation" "cloudfront" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront.arn
  validation_record_fqdns = [for record in aws_route53_record.cloudfront_validation : record.fqdn]
}
