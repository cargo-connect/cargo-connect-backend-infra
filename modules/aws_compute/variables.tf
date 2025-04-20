# Input variables for the aws_compute module (EC2 focused)

variable "project_name" {
  description = "The base name for the project, used for naming and tagging resources."
  type        = string
}

variable "environment" {
  description = "The name of the environment (e.g., dev, staging, prod)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where compute resources should be deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of IDs of the public subnets for EC2 deployment."
  type        = list(string)
}

variable "ecr_repo_name" {
  description = "The base name for the ECR repository."
  type        = string
}

variable "ecr_image_tag" {
  description = "The tag of the container image in ECR to deploy (e.g., 'latest', 'sha-xxxxx')."
  type        = string
  default     = "latest"
}

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

variable "allowed_ssh_cidr_blocks" {
  description = "List of CIDR blocks allowed for SSH access (port 22)."
  type        = list(string)
  default     = ["0.0.0.0/0"] # WARNING: Defaults to open access! Override in tfvars.
}

variable "allowed_app_cidr_blocks" {
  description = "List of CIDR blocks allowed for application access (port 8000)."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Defaults to open access. Override if needed.
}

