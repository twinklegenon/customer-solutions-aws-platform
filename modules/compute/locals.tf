##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}, e.g. dev-alb.
locals {
  name_prefix = var.environment
}
