# Input variables for the aws_network module

variable "project_name" {
  description = "The base name for the project, used for naming and tagging resources."
  type        = string
}

variable "environment" {
  description = "The name of the environment (e.g., dev, staging, prod) for resource tagging/naming."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "private_subnet_cidrs" { # Renamed from private_subnets
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "public_subnet_cidrs" { # Renamed from public_subnets
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}
