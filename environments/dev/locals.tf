locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }
}

# Port the load balancer listens on: 443 with a certificate, 80 without (demo).
locals {
  alb_port = var.certificate_arn == null ? 80 : 443
}
