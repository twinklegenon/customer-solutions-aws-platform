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
