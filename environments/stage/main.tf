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

  providers = {
    aws = aws.workload
  }

  environment             = var.environment
  data_subnet_ids         = module.networking.private_data_subnet_ids
  kms_key_arns            = module.security.kms_key_arns
  rds_security_group_id   = module.security.rds_security_group_id
  redis_security_group_id = module.security.redis_security_group_id

  db_instance_class           = var.db_instance_class
  db_allocated_storage        = var.db_allocated_storage
  db_multi_az                 = var.db_multi_az
  db_skip_final_snapshot      = var.db_skip_final_snapshot
  db_deletion_protection      = var.db_deletion_protection
  s3_force_destroy            = var.s3_force_destroy
  secret_recovery_window_days = var.secret_recovery_window_days
}

module "dns" {
  source = "../../modules/dns"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name = var.domain_name
}

module "compute" {
  source = "../../modules/compute"

  providers = {
    aws = aws.workload
  }

  environment             = var.environment
  region                  = var.region
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  app_subnet_ids          = module.networking.private_app_subnet_ids
  alb_security_group_id   = module.security.alb_security_group_id
  app_security_group_id   = module.security.app_security_group_id
  task_execution_role_arn = module.security.ecs_task_execution_role_arn
  task_role_arn           = module.security.ecs_task_role_arn
  certificate_arn         = module.dns.alb_certificate_arn

  task_execution_role_name = module.security.ecs_task_execution_role_name
  db_secret_arn            = module.data.db_master_secret_arn
  secrets_kms_key_arn      = module.security.kms_key_arns["secrets"]
  health_check_path        = "/health"
  image_repository_name    = var.app_image_repository
  image_tag                = var.app_image_tag

  container_environment = {
    APP_ENV       = var.environment
    PORT          = "8443"
    DB_HOST       = module.data.db_address
    DB_PORT       = tostring(module.data.db_port)
    DB_NAME       = module.data.db_name
    DB_SSLMODE    = "require"
    REDIS_HOST    = module.data.redis_primary_endpoint
    REDIS_PORT    = "6379"
    REDIS_TLS     = "true"
    COOKIE_SECURE = "true"
  }

  container_secrets = [
    { name = "DB_USER", valueFrom = "${module.data.db_master_secret_arn}:username::" },
    { name = "DB_PASSWORD", valueFrom = "${module.data.db_master_secret_arn}:password::" },
  ]

  min_tasks = var.ecs_min_tasks
  max_tasks = var.ecs_max_tasks

  alb_deletion_protection = var.alb_deletion_protection
  alb_logs_force_destroy  = var.s3_force_destroy
}

module "edge" {
  source = "../../modules/edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment                        = var.environment
  zone_id                            = module.dns.zone_id
  app_domain                         = module.dns.app_domain
  origin_domain                      = module.dns.origin_domain
  cloudfront_certificate_arn         = module.dns.cloudfront_certificate_arn
  alb_dns_name                       = module.compute.alb_dns_name
  alb_zone_id                        = module.compute.alb_zone_id
  static_bucket_name                 = module.data.static_bucket_name
  static_bucket_arn                  = module.data.static_bucket_arn
  static_bucket_regional_domain_name = module.data.static_bucket_regional_domain_name
}

# Pilot light: only the read replica runs in the DR region; compute is rebuilt on failover.
module "dr" {
  source = "../../modules/dr"
  count  = var.enable_dr ? 1 : 0

  providers = {
    aws = aws.dr
  }

  environment            = var.environment
  vpc_cidr               = var.dr_vpc_cidr
  subnets                = var.dr_subnets
  source_db_arn          = module.data.db_arn
  db_instance_class      = var.db_instance_class
  db_skip_final_snapshot = var.db_skip_final_snapshot
  db_deletion_protection = var.db_deletion_protection
  alarm_email            = var.alarm_email
}

module "observability" {
  source = "../../modules/observability"

  environment = var.environment
  region      = var.region
  alarm_email = var.alarm_email

  sns_kms_key_arn            = module.security.kms_key_arns["sns"]
  alb_arn_suffix             = module.compute.alb_arn_suffix
  target_group_arn_suffix    = module.compute.target_group_arn_suffix
  ecs_cluster_name           = module.compute.ecs_cluster_name
  ecs_service_name           = module.compute.ecs_service_name
  app_log_group_name         = module.compute.app_log_group_name
  db_instance_identifier     = module.data.db_identifier
  redis_replication_group_id = module.data.redis_replication_group_id
  cloudfront_distribution_id = module.edge.distribution_id
  waf_web_acl_name           = module.edge.web_acl_name

  dr_region             = var.dr_region
  dr_replica_identifier = var.enable_dr ? module.dr[0].replica_identifier : ""
}
