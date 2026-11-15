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

module "data" {
  source = "../../modules/data"

  environment             = var.environment
  data_subnet_ids         = module.networking.private_data_subnet_ids
  kms_key_arns            = module.security.kms_key_arns
  rds_security_group_id   = module.security.rds_security_group_id
  redis_security_group_id = module.security.redis_security_group_id

  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  db_multi_az            = var.db_multi_az
  db_skip_final_snapshot = var.db_skip_final_snapshot
  db_deletion_protection = var.db_deletion_protection
  s3_force_destroy       = var.s3_force_destroy
}
