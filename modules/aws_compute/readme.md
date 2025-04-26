# Terraform Module: `aws_compute`

This module provisions the core compute resources for the backend application within AWS, focusing on a single EC2 instance setup suitable for container deployment via an external CI/CD pipeline.

It sets up the following:

*   **ECR Repository:** An Elastic Container Registry repository to store the backend application's Docker images.
*   **IAM Role & Instance Profile:** An IAM role allowing the EC2 instance to interact with other AWS services (specifically ECR for pulling images and CloudWatch Logs).
*   **Security Group:** A security group attached to the EC2 instance, controlling inbound and outbound traffic. By default, it allows SSH, HTTP, and HTTPS traffic from specified CIDR blocks.
*   **EC2 Instance:** An EC2 instance launched into a public subnet.
    *   Uses the latest Ubuntu 22.04 LTS AMI.
    *   Bootstrapped using `user_data` to install prerequisites:
        *   Docker Engine
        *   AWS CLI v2
        *   jq (JSON processor)
        *   Nginx Web Server
    *   The `user_data` also configures Nginx to act as a reverse proxy:
        *   Listens on port 443 (HTTPS).
        *   Uses a **self-signed TLS certificate** (generated on first boot) for encryption.
        *   Redirects all HTTP (port 80) traffic to HTTPS (port 443).
        *   Proxies incoming HTTPS requests to the backend application container (expected to run on `127.0.0.1:8000`).
*   **Elastic IP (EIP):** Associates a static public IP address with the EC2 instance for a stable endpoint.

**Note:** This module prepares the instance environment. The actual deployment (pulling and running the application container) is expected to be handled by an external process, such as a CI/CD pipeline (e.g., GitHub Actions using SSH).

## Inputs

| Name                      | Description                                                                                                | Type         | Default         | Required |
| :------------------------ | :--------------------------------------------------------------------------------------------------------- | :----------- | :-------------- | :------- |
| `project_name`            | The base name for the project, used for naming and tagging resources.                                      | `string`     | n/a             | yes      |
| `environment`             | The name of the environment (e.g., "dev", "staging", "prod").                                              | `string`     | n/a             | yes      |
| `vpc_id`                  | The ID of the VPC where compute resources should be deployed.                                              | `string`     | n/a             | yes      |
| `public_subnet_ids`       | List of IDs of the public subnets for EC2 deployment. The instance will be placed in the first subnet listed. | `list(string)` | n/a             | yes      |
| `ecr_repo_name`           | The base name for the ECR repository (e.g., "backend-app").                                                | `string`     | n/a             | yes      |
| `ecr_image_tag`           | The default/initial tag for the container image in ECR (CI/CD likely uses specific tags like commit SHA).    | `string`     | `"latest"`      | no       |
| `ec2_instance_type`       | The instance type for the EC2 server.                                                                      | `string`     | `"t2.micro"`    | no       |
| `ec2_key_name`            | The name of the EC2 key pair to associate with the instance for SSH access.                                | `string`     | n/a             | yes      |
| `allowed_ssh_cidr_blocks` | List of CIDR blocks allowed for SSH access (port 22). **WARNING:** Defaults to `["0.0.0.0/0"]` (open access)! | `list(string)` | `["0.0.0.0/0"]` | no       |
| `allowed_app_cidr_blocks` | List of CIDR blocks allowed for HTTP (80) and HTTPS (443) access.                                          | `list(string)` | `["0.0.0.0/0"]` | no       |

*(Note: The `allowed_app_cidr_blocks` variable controls access to the Nginx proxy ports 80 and 443. The EC2 security group also includes a rule allowing port 8000 from these same CIDRs, although direct access to 8000 is generally not needed when using the Nginx proxy.)*

## Outputs

| Name                     | Description                                                              |
| :----------------------- | :----------------------------------------------------------------------- |
| `ec2_instance_id`        | The ID of the EC2 instance created.                                      |
| `ec2_instance_public_ip` | The public IP address assigned to the EC2 instance via Elastic IP.       |
| `ec2_security_group_id`  | The ID of the security group created for the EC2 instance.               |
| `ecr_repository_url`     | The URL of the ECR repository created for the backend application image. |

## Usage Example (within an environment `main.tf`)

```terraform
module "aws_compute" {
  source = "../../modules/aws_compute"

  project_name            = var.project_name
  environment             = var.environment
  vpc_id                  = module.aws_network.vpc_id
  public_subnet_ids       = module.aws_network.public_subnet_ids # Pass public subnets for EC2
  ecr_repo_name           = var.ecr_repo_name
  ecr_image_tag           = var.ecr_image_tag     # Optional, defaults to "latest"
  ec2_instance_type       = var.ec2_instance_type # Optional, defaults to "t2.micro"
  ec2_key_name            = var.ec2_key_name      # Required
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks # Optional, defaults to open
  allowed_app_cidr_blocks = var.allowed_app_cidr_blocks # Optional, defaults to open
}
```

## Self-Signed Certificate Warning

The Nginx configuration uses a self-signed TLS certificate generated during instance boot. This means clients (browsers, API tools) connecting via HTTPS will show security warnings that must be manually bypassed. This approach is used to provide encryption without requiring a custom domain name, suitable for internal testing or development environments where certificate trust is not paramount.
