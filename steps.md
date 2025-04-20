# Cargo Connect: Minimal Backend Deployment Guide (AWS EC2 + Terraform + GitHub Actions)

This guide provides a step-by-step process for setting up and deploying the Cargo Connect backend application infrastructure using Terraform, focusing on provisioning an **EC2** instance ready for container deployment via CI/CD using SSH.

## Prerequisites

*   **AWS Account:** An active AWS account with billing enabled.
*   **GitHub Account:** A GitHub account to host the repositories.
*   **Two Separate Git Repositories:**
    1.  `cargo-connect-infra`: Contains only the Terraform code for infrastructure (this repository).
    2.  `cargo-connect-backend`: Contains the Python/FastAPI backend code, the `Dockerfile`, and the backend deployment GitHub Actions workflow (`.github/workflows/deploy-backend.yml`).
*   **Tools Installed Locally:**
    *   Git
    *   Terraform CLI
    *   AWS CLI
    *   Docker
*   **Secure Storage:** A method to securely store sensitive credentials (e.g., password manager). **Do not commit secrets to Git.**
*   **EC2 Key Pair:** An EC2 Key Pair created in your target AWS region for SSH access. The **private key** file will be needed for GitHub Secrets.
*   **Your Public IP Address:** Needed to restrict SSH access in `terraform.tfvars`. You can find this by searching "what is my IP" in a web browser.

## Phase 1: Initial Cloud & Account Setup (One-Time - DevOps Role)

1.  **Create AWS Account:**
    *   Sign up for an AWS account at [aws.amazon.com](https://aws.amazon.com/).
    *   **Security Best Practice:** Secure your root user account (enable MFA, create an admin IAM user for daily tasks, and avoid using the root user).
    *   Set up billing alerts to monitor costs.

2.  **Create IAM User for Terraform Administration:**
    *   In the AWS IAM console, create a new IAM user (e.g., `terraform-admin`).
    *   Grant this user **Programmatic access** (generate Access Key ID and Secret Access Key).
    *   **Store these credentials securely.**
    *   Attach policies granting necessary permissions. For initial setup, `AdministratorAccess` is simplest, but **refine to least privilege** later. Minimally, it needs permissions for S3 (for Terraform backend), DynamoDB (for Terraform backend), IAM (for OIDC setup), VPC, EC2, ECR, and potentially CloudWatch Logs.

3.  **Configure Local AWS CLI:**
    *   Configure your local AWS CLI with the `terraform-admin` credentials:
        ```bash
        aws configure
        # Enter Access Key ID, Secret Access Key, default region, default output format
        ```

4.  **Create Terraform Backend Resources (Manual):**
    *   Using the AWS console or the configured AWS CLI, create the following resources in your desired primary AWS region (e.g., `us-east-1`):
        *   **S3 Bucket:**
            *   Name: Choose a globally unique name (e.g., `terraform-state-YOUR_PROJECT-YOUR_UNIQUE_ID`).
            *   Enable **Versioning**.
            *   Enable **Server-side encryption**.
            *   Block all public access.
        *   **DynamoDB Table:**
            *   Name: Choose a unique name (e.g., `terraform-lock-YOUR_PROJECT`).
            *   Primary key: `LockID` (Type: String).
            *   Use default settings (On-demand capacity is fine).

## Phase 2: Initial Infrastructure Provisioning (DevOps Role)

5.  **Clone Infra Repo & Configure Backend:**
    *   Clone your `cargo-connect-infra` repository locally.
    *   Navigate to `cargo-connect-infra/environments/dev`.
    *   Edit `backend.tf`:
        *   Update the `bucket` value to the exact S3 bucket name created in Step 4.
        *   Update the `dynamodb_table` value to the exact DynamoDB table name created in Step 4.
        *   Ensure the `region` matches where you created the backend resources.

6.  **Prepare Terraform Variables (Dev Environment):**
    *   Still in `cargo-connect-infra/environments/dev`:
    *   Edit the `terraform.tfvars` file:
        *   Fill in non-sensitive variable values, such as:
            *   `project_name`: Your project's base name (e.g., "cargo-connect"). Used for naming/tagging.
            *   `environment_name`: "dev"
            *   `aws_region`: Your target AWS deployment region (e.g., "us-east-1").
            *   `vpc_cidr`, `vpc_private_subnets`, `vpc_public_subnets`: Define your network layout.
            *   `ec2_instance_type`: e.g., "t2.micro" (ensure it's free-tier eligible if desired).
            *   `ec2_key_name`: **The name of the EC2 Key Pair you created.**
            *   `ecr_repo_name`: Base name for your ECR repository (e.g., "backend-app").
            *   `ecr_image_tag`: Initial tag (e.g., "latest"). CI/CD will deploy specific tags later.
            *   `allowed_ssh_cidr_blocks`: **Replace `["YOUR_IP/32"]` with a list containing your actual public IP address followed by `/32`. Example: `["1.2.3.4/32"]`. This is crucial for security.**
            *   `allowed_app_cidr_blocks`: Keep as `["0.0.0.0/0"]` if the API needs to be publicly accessible, or restrict as needed.
    *   *(No sensitive variables needed for this minimal setup unless added later)*

7.  **Run Terraform (Dev Environment):**
    *   From the `cargo-connect-infra/environments/dev` directory:
        ```bash
        terraform init  # Initializes providers and backend configuration
        terraform validate # Check syntax
        terraform plan # Review planned changes (reads terraform.tfvars automatically)
        terraform apply # Apply changes (type 'yes' to confirm)
        ```
    *   This command provisions the core AWS resources: VPC, ECR, **EC2 Instance**, Security Groups, IAM Roles. The EC2 instance's `user_data` script **only installs prerequisites** like Docker and AWS CLI. **It does NOT pull or run your application container.**

8.  **Retrieve Terraform Outputs:**
    *   After a successful `apply`, while still in `environments/dev`, run:
        ```bash
        terraform output
        ```
    *   Note down the key output values:
        *   `ecr_repository_url`: The URL of the ECR repository for the backend Docker images.
        *   `ec2_instance_public_ip`: The public IP address of the deployed EC2 instance (this is your API endpoint base URL).
        *   `ec2_instance_id`: The ID of the created EC2 instance (needed for deployment targeting).
        *   `aws_region`: The AWS region used for deployment.

## Phase 3: CI/CD Setup (DevOps Role)

9.  **Configure AWS IAM OIDC Provider for GitHub Actions:**
    *   In the AWS IAM console:
        *   Go to Identity Providers -> Add provider.
        *   Select **OpenID Connect**.
        *   Provider URL: `https://token.actions.githubusercontent.com`
        *   Audience: `sts.amazonaws.com`
        *   **Verify Thumbprint (Auto-retrieved):** AWS should automatically retrieve the thumbprint for this provider. Proceed to the next step unless you encounter an error or need to manually verify/provide it for specific reasons.
        *   Click "Add provider".

10. **Create IAM Role for GitHub Actions (Dev Environment):**
    *   Create **one** new IAM Role specifically for the `dev` environment:
        *   **Role: Backend Deployment (`GitHubActions-YOUR_PROJECT-BackendDeployRole-Dev`)**
            *   Trusted entity type: **Web identity**.
            *   Identity provider: Select the GitHub OIDC provider created above.
            *   Audience: `sts.amazonaws.com`.
            *   GitHub organization/repository: Specify your org and the **backend application** repository.
            *   **Permissions:** Attach policies allowing the workflow **only to push to ECR**. The SSH action uses separate credentials (the EC2 private key) and the EC2 instance uses its own instance profile for ECR login during deployment.
                *   **Option A (Managed Policy):** `AmazonEC2ContainerRegistryPowerUser`
                *   **Option B (More Secure):** Create a custom inline policy granting specific ECR permissions, scoped down to your ECR repository ARN. Example JSON structure (replace placeholders):
                  ```json
                  {
                      "Version": "2012-10-17",
                      "Statement": [
                          {
                              "Sid": "AllowECRPush",
                              "Effect": "Allow",
                              "Action": [
                                  "ecr:BatchCheckLayerAvailability",
                                  "ecr:CompleteLayerUpload",
                                  "ecr:GetAuthorizationToken",
                                  "ecr:InitiateLayerUpload",
                                  "ecr:PutImage",
                                  "ecr:UploadLayerPart"
                              ],
                              "Resource": "arn:aws:ecr:YOUR_REGION:YOUR_ACCOUNT_ID:repository/YOUR_ECR_REPO_NAME"
                          },
                          {
                              "Sid": "AllowECRAuth",
                              "Effect": "Allow",
                              "Action": "ecr:GetAuthorizationToken",
                              "Resource": "*"
                          }
                      ]
                  }
                  ```
                  Then attach this newly created custom policy to the role.
    *   **Note the ARN** of this created role.

11. **Configure GitHub Secrets:**
    *   **In your backend application repository:**
        *   Go to Settings -> Secrets and variables -> Actions -> New repository secret:
            *   `AWS_REGION`: The value of `aws_region` from Terraform output (Step 8).
            *   `AWS_ROLE_TO_ASSUME`: The ARN of the `GitHubActions-YOUR_PROJECT-BackendDeployRole-Dev` created in Step 10.
            *   `ECR_REPOSITORY_URL`: The value of `ecr_repository_url` from Terraform output (Step 8).
            *   `EC2_HOST`: The value of `ec2_instance_public_ip` from Terraform output (Step 8).
            *   `EC2_USERNAME`: The SSH username for the EC2 instance (e.g., `ubuntu` for Ubuntu AMIs).
            *   `EC2_SSH_PRIVATE_KEY`: The **contents** of the private key file (`.pem` or similar) downloaded when you created the EC2 Key Pair. **Handle this very carefully.**
            *   `DATABASE_URL`: Your application's database connection string (e.g., `sqlite:////app/cargoconnect.db` if using SQLite within the container, or connection string for an external DB).
            *   `SECRET_KEY`: Your application's secret key.
            *   `MAIL_SERVER`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`: Your mail server credentials.
            *   *(Add any other secrets your application requires)*

12. **Add/Verify Workflow File:**
    *   Ensure the backend deployment workflow file (e.g., `deploy-backend.yml`) exists in `.github/workflows/` in the backend application repository. This workflow should use the `appleboy/ssh-action` (or similar) as you provided:
        *   Check out the code.
        *   Configure AWS credentials using the OIDC role (`AWS_ROLE_TO_ASSUME`) - *only needed for ECR push*.
        *   Log in to the AWS ECR registry (`ECR_REPOSITORY_URL`).
        *   Build the Docker image using the `Dockerfile`.
        *   Determine the new image tag (e.g., Git SHA).
        *   Push the tagged image(s) to ECR.
        *   **Use the `appleboy/ssh-action`:**
            *   Provide `host`, `username`, `key` from GitHub secrets (`EC2_HOST`, `EC2_USERNAME`, `EC2_SSH_PRIVATE_KEY`).
            *   Pass necessary application secrets (`DATABASE_URL`, `SECRET_KEY`, etc.) from GitHub Secrets into the action's `env` context.
            *   The `script` within the SSH action should perform:
                *   `aws ecr get-login-password ... | docker login ...` (Login on the instance using its *Instance Profile* permissions)
                *   `docker pull <ECR_REPOSITORY_URL>:<new-tag>`
                *   `docker stop <your-app-container-name> || true`
                *   `docker rm <your-app-container-name> || true`
                *   `docker run -d --name <your-app-container-name> -p 8000:8000 --restart always -e ENVIRONMENT=dev -e DATABASE_URL="$DATABASE_URL_SECRET" -e SECRET_KEY="$SECRET_KEY_SECRET" ... <ECR_REPOSITORY_URL>:<new-tag>` (Inject secrets from env context)

## Phase 4: Development & Deployment Cycle (Developer Role)

13. **Develop & Push Backend Code:**
    *   Developers work on the backend application within its repository.
    *   Commit and push changes to the branch configured to trigger the `deploy-backend.yml` workflow (e.g., `main`).
    *   **Result:** The GitHub Action automatically triggers, builds the Docker image, pushes it to ECR, and **triggers the deployment via SSH** to update the container running on the EC2 instance.

14. **Testing:**
    *   Access the backend API directly via `http://<EC2_PUBLIC_IP_FROM_STEP_8>:8000/docs` (or other relevant paths). Allow time for the deployment step in the workflow to complete.

15. **Updating Running Backend Container (Manual Alternatives):**
    *   If the CI/CD pipeline fails or for emergency manual updates:
        *   **Option A (SSH - Manual):** SSH into the EC2 instance using the key pair specified in `terraform.tfvars`. Manually run `docker pull <image_uri>:<tag>`, `docker stop <container_name>`, `docker rm <container_name>`, and `docker run ...` (including all `-e` flags for secrets).
        *   **Option B (Terraform - Re-provision):** Update the `ecr_image_tag` variable in `terraform.tfvars` to the new tag, then run `terraform apply`. This will replace the EC2 instance, causing downtime but ensuring the new image is used. (Note: The primary update method should be the CI/CD pipeline described in Step 12).

## Phase 5: Maintenance & Iteration

*   **Application Updates:** Continue the development cycle (Step 13) by pushing code changes. CI/CD handles the build, push, and deployment via SSH.
*   **Infrastructure Updates:**
    *   Modify Terraform code in the `cargo-connect-infra` repository.
    *   Navigate to `cargo-connect-infra/environments/dev`.
    *   Run `terraform plan` and `terraform apply`.
    *   **Important:** If infrastructure changes affect outputs used in CI/CD (like ECR URL, region, public IP), update the corresponding GitHub Secrets (Step 11).
*   **Adding New Environments (e.g., Staging, Prod):**
    *   Duplicate the `environments/dev` directory.
    *   Create corresponding `.tfvars` files.
    *   Update the `backend.tf` if needed.
    *   Run `terraform init` and `terraform apply` for the new environment.
    *   Retrieve outputs.
    *   In AWS IAM: Create new OIDC roles specific to the new environment.
    *   In GitHub: Configure new secrets for the new environment (including SSH key, host, username, app secrets).
    *   Adjust GitHub Actions workflows.
