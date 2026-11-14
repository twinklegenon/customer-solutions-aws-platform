##################################
# Reusable Infrastructure Layers
##################################

module "networking" {
  source = "../../modules/network"

  environment = var.environment
  region      = var.region
  subnets     = var.subnets
  vpc_cidr    = var.vpc_cidr
}
