# stage.tfvars (sample; alarm_email comes from the CI/CD variable TF_VAR_alarm_email)

# Tags
project     = "customer-solutions-platform"
environment = "stage"
owner       = "devops"
cost_center = "cc-devops-shared"

# Workload tags
service              = "web"
workload_owner       = "web"
workload_cost_center = "cc-web"

# Region
region = "ap-southeast-1"

# Network (module.networking)
vpc_cidr = "10.30.0.0/16"

subnets = {
  "ap-southeast-1a" = { public = "10.30.0.0/24", app = "10.30.10.0/24", data = "10.30.20.0/24" }
  "ap-southeast-1b" = { public = "10.30.1.0/24", app = "10.30.11.0/24", data = "10.30.21.0/24" }
}

# Data (module.data): same topology as prod, smaller class and disk.
db_instance_class    = "db.t4g.small"
db_allocated_storage = 50
db_multi_az          = true

# Safe settings: keep a final snapshot, block deletion, keep non-empty buckets.
db_skip_final_snapshot = false
db_deletion_protection = true
s3_force_destroy       = false

# Compute (module.compute)
alb_deletion_protection = true

# ECR repository of the stage account (created manually) and the image version to run.
app_image_repository = "stage-ecr-app"
app_image_tag        = "1.0.1"

# DNS and edge: needs a hosted zone for this domain in the stage account.
domain_name = "stage.customersolutionslab.com"

# Disaster recovery (module.dr): off in stage, on in prod.
enable_dr   = false
dr_region   = "ap-southeast-2"
dr_vpc_cidr = "10.50.0.0/16"
dr_subnets = {
  "ap-southeast-2a" = "10.50.20.0/24"
  "ap-southeast-2b" = "10.50.21.0/24"
}
