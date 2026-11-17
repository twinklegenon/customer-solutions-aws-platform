locals {
  # Platform resources (network, security, edge, observability) are shared.
  common_tags = {
    Project     = var.project
    Environment = var.environment
    Service     = "shared"
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }

  # Workload resources (compute, data, dr): the owning team's values replace Service, Owner and CostCenter.
  workload_tags = merge(local.common_tags, {
    Service    = var.service
    Owner      = var.workload_owner
    CostCenter = var.workload_cost_center
  })
}
