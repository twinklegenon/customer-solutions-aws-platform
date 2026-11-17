# prod.tfvars (sample; alarm_email comes from the CI/CD variable TF_VAR_alarm_email)

# Tags
project     = "customer-solutions-platform"
environment = "prod"
owner       = "devops"
cost_center = "cc-devops-shared"

# Workload tags
service              = "web"
workload_owner       = "web"
workload_cost_center = "cc-web"

# Region
region = "ap-southeast-1"

# Network (module.networking)
vpc_cidr = "10.40.0.0/16"

subnets = {
  "ap-southeast-1a" = { public = "10.40.0.0/24", app = "10.40.10.0/24", data = "10.40.20.0/24" }
  "ap-southeast-1b" = { public = "10.40.1.0/24", app = "10.40.11.0/24", data = "10.40.21.0/24" }
}

# Data (module.data): production class and disk, Multi-AZ.
db_instance_class    = "db.m6g.large"
db_allocated_storage = 100
db_multi_az          = true

# Safe settings: keep a final snapshot, block deletion, keep non-empty buckets.
db_skip_final_snapshot = false
db_deletion_protection = true
s3_force_destroy       = false

# Compute (module.compute)
ecs_min_tasks           = 2 # one per AZ
ecs_max_tasks           = 6
alb_deletion_protection = true

# ECR repository of the prod account (created manually) and the image version to run.
app_image_repository = "prod-ecr-app"
app_image_tag        = "1.0.1"

# DNS and edge: needs a hosted zone for this domain in the prod account.
domain_name = "prod.customersolutionslab.com"

# Disaster recovery (module.dr): on in prod, a read replica in Sydney.
enable_dr   = true
dr_region   = "ap-southeast-2"
dr_vpc_cidr = "10.60.0.0/16"
dr_subnets = {
  "ap-southeast-2a" = "10.60.20.0/24"
  "ap-southeast-2b" = "10.60.21.0/24"
}
