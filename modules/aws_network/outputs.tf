# Outputs from the aws_network module

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = module.vpc.public_subnets
}

