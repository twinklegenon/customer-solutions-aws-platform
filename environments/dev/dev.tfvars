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

# Dev only: allow a quick destroy. Stage and prod keep the safe defaults.
db_skip_final_snapshot = true
db_deletion_protection = false
s3_force_destroy       = true
