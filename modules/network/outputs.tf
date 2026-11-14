##################################
# Interfaces
##################################

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main_vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main_vpc.cidr_block
}

output "azs" {
  description = "Availability zones in use"
  value       = keys(var.subnets)
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB)"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs (ECS)"
  value       = [for subnet in aws_subnet.private_app : subnet.id]
}

output "private_data_subnet_ids" {
  description = "Private data subnet IDs (RDS, Redis)"
  value       = [for subnet in aws_subnet.private_data : subnet.id]
}
