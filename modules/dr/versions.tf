##################################
# Root Configuration
##################################

# The calling environment passes the DR region provider as the default "aws" of this module.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
