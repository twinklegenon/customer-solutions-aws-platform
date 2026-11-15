##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}-{az}, e.g. dev-subnet-public-1a.
locals {
  name_prefix = var.environment
}
