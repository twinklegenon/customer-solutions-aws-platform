# dev.tfvars
project     = "customer-solutions-platform"
environment = "dev"
owner       = "devops"
cost_center = "cc-devops-shared"

vpc_cidr = "10.10.0.0/16"

region = "ap-southeast-1"

subnets = {
  "ap-southeast-1a" = { public = "10.10.0.0/24", app = "10.10.10.0/24", data = "10.10.20.0/24" }
  "ap-southeast-1b" = { public = "10.10.1.0/24", app = "10.10.11.0/24", data = "10.10.21.0/24" }
}

# Database sizing (dev and test: smallest class, small disk).
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_multi_az          = true

# Dev only, for demo: allow a quick destroy. Best practice (stage and prod) is the opposite.
db_skip_final_snapshot = true  # best practice: false (keep a final snapshot)
db_deletion_protection = false # best practice: true (block accidental deletion)
s3_force_destroy       = true  # best practice: false (never delete a bucket that has objects)

# Domain registered in Route 53. Users visit app.<domain>; CloudFront reaches the load balancer at origin.<domain>.
domain_name = "customersolutionslab.com"

# Dev only, for demo: allow a quick destroy.
alb_deletion_protection = false # best practice: true (block accidental deletion)

# ECR repository (created manually, outside Terraform) and the version tag of the application image to run.
app_image_repository = "dev-ecr-app"
app_image_tag        = "1.0.1"

# Disaster recovery (pilot light): a read replica in a second region. Turn it on only for a demo window.
enable_dr   = true
dr_region   = "ap-southeast-2"
dr_vpc_cidr = "10.20.0.0/16"
dr_subnets = {
  "ap-southeast-2a" = "10.20.20.0/24"
  "ap-southeast-2b" = "10.20.21.0/24"
}
