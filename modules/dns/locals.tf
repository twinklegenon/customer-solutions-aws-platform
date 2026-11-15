##################################
# Environment-Specific Resources
##################################

locals {
  app_domain    = "${var.app_subdomain}.${var.domain_name}"
  origin_domain = "${var.origin_subdomain}.${var.domain_name}"
}
