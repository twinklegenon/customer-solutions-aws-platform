##################################
# Root Configuration
##################################

# A CloudFront web ACL (WAF) can only be created in us-east-1, so this module takes a second provider.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
