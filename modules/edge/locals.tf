##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}, e.g. dev-waf-cloudfront.
locals {
  name_prefix = var.environment
}
