##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}, e.g. dev-rds.
locals {
  name_prefix = var.environment
}
