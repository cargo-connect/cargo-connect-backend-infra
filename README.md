# Cargo Connect - Infrastructure Repository (Minimal Backend)

This repository contains the Terraform code for provisioning and managing the minimal cloud infrastructure for the Cargo Connect backend application. It uses a modular approach with environment separation, focusing on provisioning an EC2 instance ready for container deployment via CI/CD.

**For a comprehensive, step-by-step guide covering initial cloud setup, CI/CD configuration, and deployment, please refer to the [Deployment Guide (steps.md)](steps.md).**

## Repository Structure

The repository is organized as follows:

```
cargo-connect-infra/
├── .gitignore        # Standard Terraform ignores
├── environments/     # Root modules for each deployment environment
│   └── dev/          # Configuration for the 'dev' environment
│       ├── backend.tf      # Backend config for dev state
│       ├── terraform.tfvars      # Variable values for dev (gitignored)
│       ├── main.tf         # Calls modules for dev environment
│       ├── outputs.tf      # Outputs specific to dev environment
│       ├── providers.tf    # Provider configs for dev
│       └── variables.tf    # Variable definitions for dev environment
│   # (staging/, prod/ directories would follow the same pattern)
└── modules/          # Reusable infrastructure modules
    ├── aws_compute/      # AWS Compute (ECR, EC2, IAM, SG, EIP)
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── aws_network/      # AWS Networking (VPC, Subnets)
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

*   **`environments/`**: Contains one subdirectory per deployment environment (e.g., `dev`, `staging`, `prod`). Each environment directory is a Terraform root module. You run `terraform` commands from within these directories.
*   **`modules/`**: Contains reusable Terraform modules that define specific parts of the infrastructure (networking, compute). These modules are called by the `main.tf` within each environment directory.

## Prerequisites

1.  **Terraform CLI:** Install the Terraform CLI (version >= 1.0).
2.  **AWS Credentials:** Configure AWS credentials locally (e.g., via environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, or via AWS profiles). The credentials need permissions to create/manage the resources defined in the modules (VPC, EC2, ECR, IAM roles/policies, S3/DynamoDB for Terraform backend, potentially SSM).
3.  **Terraform Backend:** Manually create the S3 bucket (`terraform-state-cargo-connect` or your chosen name) and DynamoDB table (`terraform-lock-cargo-connect` or your chosen name) in your desired AWS region (`us-east-1` by default) before the first run. Ensure the AWS credentials used by Terraform have permissions to access this bucket and table.
4.  **EC2 Key Pair:** Ensure you have an EC2 Key Pair created in the target AWS region.

## Provisioning an Environment (Example: dev)

1.  **Navigate to Environment Directory:**
    ```bash
    cd environments/dev
    ```
2.  **Prepare Variables:**
    *   Edit `terraform.tfvars`.
    *   Fill in the required values, especially `ec2_key_name`.
    *   For `allowed_ssh_cidr_blocks`, the `dev` environment currently uses `["0.0.0.0/0"]` for easier access (accepting the security risk), but **it is strongly recommended to restrict this to specific IP addresses (e.g., `["YOUR_IP/32"]`) for staging/production environments.**
    *   *(No sensitive variables required for this minimal setup unless added later)*
3.  **Initialize Terraform:**
    ```bash
    terraform init
    ```
    This downloads providers and initializes the backend.
4.  **Plan Changes:**
    ```bash
    terraform plan
    ```
    Review the planned actions.
5.  **Apply Changes:**
    ```bash
    terraform apply
    ```
    Confirm the prompt by typing `yes`. This provisions the infrastructure, including the EC2 instance with Docker installed, but **does not deploy the application container**.

Repeat these steps for other environments (staging, prod) by creating corresponding directories and `.tfvars` files under `environments/`.

## Variable Management

*   Variables for each environment are defined in `environments/<env>/variables.tf`.
*   Non-sensitive, environment-specific values are provided in `environments/<env>/terraform.tfvars`.
*   **Sensitive values** (if added later) **MUST** be provided via environment variables prefixed with `TF_VAR_`.

## Architecture Diagram (Minimal - Infra Only)

```mermaid
graph TD
  subgraph AWS Cloud
    subgraph VPC
        EC2[EC2 Instance<br/>(Docker Ready)]
    end
    ECR[(ECR Repo)]
    IAM{IAM Role<br/>(EC2 Instance Profile)}
    CloudWatch[(CloudWatch Logs)]

    EC2 -- Assumes --> IAM # For ECR pull, CloudWatch, potentially SSM
    EC2 --> CloudWatch
  end

  subgraph GitHub
    GitHubActions[GitHub Actions<br/>CI/CD workflows] -- OIDC --> IAM_OIDC{OIDC Role}
    GitHubActions -- Push Image --> ECR
    GitHubActions -- Deploy Cmd --> SSM[SSM Run Command]

    IAM_OIDC --> ECR # Granting push permission
    IAM_OIDC --> SSM # Granting send-command permission
  end

  SSM -- Executes On --> EC2

  User((User / Client)) -- HTTP --> EC2_IP[EC2 Public IP]:80/8000
  EC2_IP --> EC2

```
*Note: Application deployment (Docker pull/run on EC2) is triggered by the GitHub Actions workflow, typically via SSM Run Command, after Terraform provisions the base infrastructure.*

## Maintenance

*   To modify infrastructure for an environment, make changes to the variables in the corresponding `terraform.tfvars` file or update resource configurations within the relevant `modules/` directory.
*   Navigate to the environment directory (`cd environments/<env>`).
*   Run `terraform plan` to review changes.
*   Run `terraform apply` to apply changes.
*   Application updates are handled via the CI/CD pipeline in the application repository (`cargo-connect-backend`).

## Modules Overview

*   **`aws_network`**: Creates the VPC, public/private subnets, NAT Gateway/Internet Gateway.
*   **`aws_compute`**: Creates the ECR repository, EC2 instance (bootstrapped with Docker), IAM role/profile, Security Group, and Elastic IP.
