##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}, e.g. dev-sg-alb.
locals {
  name_prefix = var.environment
}
