##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-dr, e.g. dev-rds-dr.
locals {
  name_prefix = var.environment
}
