##################################
# Environment-Specific Resources
##################################

# Naming: {env}-{resource}-{tier}, e.g. dev-alb.
locals {
  name_prefix = var.environment

  # The ECR repository is created outside Terraform; tasks pull from it through the VPC endpoints.
  image_repository_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.image_repository_name}"
}
