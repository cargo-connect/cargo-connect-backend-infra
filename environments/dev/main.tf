# This main.tf file defines the infrastructure for the 'dev' environment
# by calling reusable modules from the ../../modules directory.

# Provider configuration will be in providers.tf
# Backend configuration will be in backend.tf
# Variable values specific to dev are in terraform.tfvars

# --- AWS Modules ---

module "aws_network" {
  source = "../../modules/aws_network"

  project_name         = var.project_name
  environment          = var.environment # Use renamed variable
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs # Use renamed variable
  public_subnet_cidrs  = var.public_subnet_cidrs # Use renamed variable
}


module "aws_compute" {
  source = "../../modules/aws_compute"

  project_name       = var.project_name
  environment        = var.environment 
  vpc_id             = module.aws_network.vpc_id
  public_subnet_ids  = module.aws_network.public_subnet_ids # Use public subnets for EC2
  ecr_repo_name      = var.ecr_repo_name
  ecr_image_tag      = var.ecr_image_tag     # Pass image tag variable
  ec2_instance_type  = var.ec2_instance_type # Pass EC2 instance type variable
  ec2_key_name       = var.ec2_key_name      # Pass EC2 key name variable

}
