##################################
# Interfaces
##################################

output "vpc_id" {
  description = "ID of the dev VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.networking.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  value = module.networking.private_data_subnet_ids
}

output "dr_replica_identifier" {
  description = "Identifier of the DR read replica (empty when DR is off)"
  value       = var.enable_dr ? module.dr[0].replica_identifier : null
}
