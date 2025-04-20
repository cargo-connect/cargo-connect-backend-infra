terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
  # Credentials sourced via standard AWS methods (env vars, profile, role)
}


