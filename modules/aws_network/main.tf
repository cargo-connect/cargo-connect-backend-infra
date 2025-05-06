# Module: aws_network
# Defines the core networking infrastructure (VPC, Subnets, NAT Gateway)

# Data source to get available AZs in the region
data "aws_availability_zones" "available" {}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0" # Use a recent version compatible with provider
  name = "${var.project_name}-vpc-${var.environment}" 
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 1) # Use 1 available AZs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = false # Needed for private subnet instances
  single_nat_gateway = false # Cost-effective for non-HA setups

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name 
  }
}
