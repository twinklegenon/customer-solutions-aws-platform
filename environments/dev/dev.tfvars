# dev.tfvars (alarm_email comes from the CI/CD variable TF_VAR_alarm_email)

# Tags
project     = "customer-solutions-platform"
environment = "dev"
owner       = "devops"
cost_center = "cc-devops-shared"

# Workload tags (Task Manager). Identity, CRM and Ecommerce get their own values when onboarded.
service              = "web"
workload_owner       = "web"
workload_cost_center = "cc-web"

# Region
region = "ap-southeast-1"

# Network (module.networking)
vpc_cidr = "10.10.0.0/16"

subnets = {
  "ap-southeast-1a" = { public = "10.10.0.0/24", app = "10.10.10.0/24", data = "10.10.20.0/24" }
  "ap-southeast-1b" = { public = "10.10.1.0/24", app = "10.10.11.0/24", data = "10.10.21.0/24" }
}

# Data (module.data): smallest class, small disk.
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_multi_az          = true

# Dev only, for demo: allow a quick destroy. Best practice (stage and prod) is the opposite.
db_skip_final_snapshot      = true  # best practice: false (keep a final snapshot)
db_deletion_protection      = false # best practice: true (block accidental deletion)
s3_force_destroy            = true  # best practice: false (never delete a bucket that has objects)
secret_recovery_window_days = 0     # best practice: 7 (a deleted secret can be recovered)

# Compute (module.compute)
ecs_min_tasks           = 2 # one per AZ
ecs_max_tasks           = 4
alb_deletion_protection = false # dev only. best practice: true (block accidental deletion)

# ECR repository (created manually, outside Terraform) and the image version to run.
app_image_repository = "dev-ecr-app"
app_image_tag        = "1.0.2"

# DNS and edge: users visit app.<domain>; CloudFront reaches the load balancer at origin.<domain>.
domain_name = "customersolutionslab.com"

# Disaster recovery (module.dr): read replica in a second region. Turn it on only for a demo window.
enable_dr   = false
dr_region   = "ap-southeast-2"
dr_vpc_cidr = "10.20.0.0/16"
dr_subnets = {
  "ap-southeast-2a" = "10.20.20.0/24"
  "ap-southeast-2b" = "10.20.21.0/24"
}
