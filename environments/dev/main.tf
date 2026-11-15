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

module "security" {
  source = "../../modules/security"

  environment = var.environment
  region      = var.region
  vpc_id      = module.networking.vpc_id
  vpc_cidr    = var.vpc_cidr
}
