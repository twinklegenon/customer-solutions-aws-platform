##################################
# Root Configuration
##################################

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# CloudFront certificates must be issued in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

# Disaster recovery region (pilot light replica).
provider "aws" {
  alias  = "dr"
  region = var.dr_region

  default_tags {
    tags = local.common_tags
  }
}
