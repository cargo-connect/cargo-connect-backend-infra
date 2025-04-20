# Outputs for the 'dev' environment

output "dev_ec2_instance_public_ip" {
  description = "The public IP address of the dev EC2 instance (API endpoint)."
  value       = module.aws_compute.ec2_instance_public_ip # Updated to EC2 output
}

output "dev_ec2_instance_id" {
  description = "The ID of the dev EC2 instance."
  value       = module.aws_compute.ec2_instance_id
}

output "dev_ecr_repository_url" {
  description = "The URL of the dev ECR repository."
  value       = module.aws_compute.ecr_repository_url
}

output "dev_aws_region" {
  description = "The AWS region used for the dev environment."
  value       = var.aws_region
}


