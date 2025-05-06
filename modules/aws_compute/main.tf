# Module: aws_compute
# Defines compute resources: ECR repo, EC2 Instance, Security Group, IAM Role/Instance Profile

# --- ECR ---

resource "aws_ecr_repository" "backend" {
  name                 = "${var.ecr_repo_name}-${var.environment}"
  image_tag_mutability = "MUTABLE" 

  image_scanning_configuration {
    scan_on_push = true 
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name
  }
}

# --- IAM Role & Instance Profile for EC2 ---
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_instance_role" {
  name               = "${var.project_name}-ec2-role-${var.environment}" # Use variable
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-ec2-profile-${var.environment}"
  role = aws_iam_role.ec2_instance_role.name

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy for ECR, S3, and CloudWatch Logs access
data "aws_iam_policy_document" "ec2_permissions_policy_doc" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = ["*"] # ECR actions require "*" for GetAuthorizationToken
    effect    = "Allow"
  }

  statement {
    actions = [
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchDeleteImage", # Optional: if cleanup is needed
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage" # Optional: if instance pushes images
    ]
    resources = [aws_ecr_repository.backend.arn]
    effect    = "Allow"
  }

  # Basic CloudWatch Logs permissions
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:*:*:*"] # Adjust region/account if needed
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "ec2_permissions_policy" {
  name        = "${var.project_name}-ec2-permissions-policy-${var.environment}" # Use variable
  description = "Policy for EC2 instance (${var.project_name}-${var.environment}) to access ECR and CloudWatch Logs" # Updated description
  policy      = data.aws_iam_policy_document.ec2_permissions_policy_doc.json

  tags = {
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name # Use variable
  }
}

resource "aws_iam_role_policy_attachment" "ec2_permissions_attach" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_permissions_policy.arn
}


# --- EC2 Security Group ---
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg-${var.environment}" # Use variable
  description = "Allow SSH and App traffic for ${var.project_name} EC2 instance (${var.environment})" # Updated description
  vpc_id      = var.vpc_id

  # Allow SSH access (Restrict cidr_blocks to your IP in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr_blocks
    description = "Allow SSH"
  }

  # Allow access to the application port (8000)
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.allowed_app_cidr_blocks
    description = "Allow App Traffic"
  }

  # Allow access via HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_app_cidr_blocks # Use the same source IPs as port 8000
    description = "Allow HTTP Traffic"
  }

  # Allow access via HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_app_cidr_blocks # Use the same source IPs as port 80/8000
    description = "Allow HTTPS Traffic"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ec2-sg-${var.environment}" # Use variable
    Environment = var.environment
    Project     = var.project_name # Use variable
  }
}

# --- Find Latest Ubuntu AMI ---
# Using Ubuntu 22.04 LTS (Jammy) AMD64 Server
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- EC2 Instance ---
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type # Use variable for instance type
 
  # Assumes var.public_subnet_ids is populated by the network module
  subnet_id              = element(var.public_subnet_ids, 0)  # Place instance in a public subnet to be reachable & pull images/updates
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  key_name               = var.ec2_key_name # Use variable for key pair name

  # monitoring to true if needed (incurs cost)
  # monitoring             = false

  # User data script to setup and run the Docker container
  user_data = <<-EOF
#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.
# Log stdout/stderr to /var/log/user-data.log and console
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user data script..."

# Install updates and Docker
apt-get update -y
# Install Docker, AWS CLI, jq (for parsing metadata)
apt-get install -y docker.io awscli jq nginx

echo "Docker, AWS CLI, Nginx installed."

# Start and enable Docker service
systemctl start docker
systemctl enable docker
echo "Docker service started and enabled."

# Add ubuntu user to docker group to run docker commands without sudo (optional, requires logout/login or newgrp)
usermod -aG docker ubuntu

# --- Setup Nginx and Self-Signed Cert for HTTPS ---
echo "Generating self-signed certificate..."
# Create directory for certs
mkdir -p /etc/nginx/ssl
# Generate cert and key (valid for 365 days, no passphrase)
# Use instance's public hostname (or IP if hostname isn't available quickly) for CN
INSTANCE_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname || curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "localhost")
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx-selfsigned.key \
    -out /etc/nginx/ssl/nginx-selfsigned.crt \
    -subj "/C=XX/ST=State/L=City/O=Org/CN=$${INSTANCE_HOSTNAME}" # Escaped $ for Terraform

echo "Configuring Nginx as reverse proxy..."
# Create Nginx config for reverse proxy
# Note: Assumes backend app runs on port 8000
cat > /etc/nginx/sites-available/default <<'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _; # Catch all hostnames

    # Proxy API requests directly over HTTP for all paths
    location / {
        proxy_pass http://127.0.0.1:8000; # Ensure this is your FastAPI app's address and port
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;

    server_name _; # Catch all hostnames

    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;

    # Improve SSL security (Optional but recommended)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    # Add other SSL settings as needed (HSTS, etc.)

    location / {
        proxy_pass http://127.0.0.1:8000; # Proxy to backend app on port 8000 (use 127.0.0.1 for clarity)        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # WebSocket support (if needed)
        # proxy_http_version 1.1;
        # proxy_set_header Upgrade $http_upgrade;
        # proxy_set_header Connection "upgrade";
    }
}
NGINX_CONF

echo "Enabling and restarting Nginx..."
systemctl enable nginx
systemctl restart nginx

# Note: Container deployment (pulling image, docker run) is handled by the CI/CD pipeline (e.g., GitHub Actions).
# Ensure the container exposes port 8000 internally for Nginx proxy_pass.

echo "User data script finished (Docker installed, Nginx HTTPS proxy configured)."
EOF

  tags = {
    Name        = "${var.project_name}-app-server-${var.environment}" # Use variable
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name # Use variable
  }

  depends_on = [
    aws_iam_instance_profile.ec2_instance_profile,
    # Ensure network resources (like subnets) are created first (implicit dependency via var.public_subnet_ids)
  ]
}

# --- Elastic IP (Optional but recommended for stable IP) ---
# Associates a static public IP with the EC2 instance.
resource "aws_eip" "static_ip" {
  # instance = aws_instance.app_server.id # Deprecated association method
  # Use association resource instead for better lifecycle management
  depends_on = [aws_instance.app_server] # Ensure instance exists first
  tags = {
    Name        = "${var.project_name}-eip-${var.environment}" # Use variable
    Terraform   = "true"
    Environment = var.environment
    Project     = var.project_name # Use variable
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.app_server.id
  allocation_id = aws_eip.static_ip.id
}
