# Input variables for the 'dev' environment root module

variable "project_name" {
  description = "The base name for the project, used for naming and tagging resources."
  type        = string
  default     = "cargo-connect" # Default project name
}

variable "environment" { # Renamed from environment_name
  description = "The name of the environment (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

# --- AWS Configuration Variables ---

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  # No default - should be provided by .tfvars or environment variables
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "private_subnet_cidrs" { # Renamed from vpc_private_subnets
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" { # Renamed from vpc_public_subnets
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}



# EC2 variables
variable "ec2_instance_type" {
  description = "The instance type for the EC2 server (e.g., t2.micro)."
  type        = string
  default     = "t2.micro" # Default to free-tier eligible
}

variable "ec2_key_name" {
  description = "The name of the EC2 key pair to associate with the instance for SSH access."
  type        = string
  # No default, should be provided by the calling module (environment)
}

variable "ecr_image_tag" {
  description = "The tag of the container image in ECR to deploy (e.g., 'latest', 'sha-xxxxx')."
  type        = string
  default     = "latest"
}

variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed for SSH access (port 22) to the EC2 instance."
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Defaults to open access! Override in tfvars.
}

variable "allowed_app_cidr_blocks" {
  description = "List of CIDR blocks allowed for application access (port 8000) to the EC2 instance."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Defaults to open access. Override if needed.
}


variable "ecr_repo_name" {
  description = "The base name for the ECR repository."
  type        = string
}
