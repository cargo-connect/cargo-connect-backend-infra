# Outputs from the aws_compute module (EC2 focused)

output "ec2_instance_id" {
  description = "The ID of the EC2 instance created."
  value       = aws_instance.app_server.id
}

output "ec2_instance_public_ip" {
  description = "The public IP address assigned to the EC2 instance via Elastic IP."
  value       = aws_eip.static_ip.public_ip
}

output "ec2_security_group_id" {
  description = "The ID of the security group created for the EC2 instance."
  value       = aws_security_group.ec2_sg.id
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.backend.repository_url
}

# Add other outputs as needed
