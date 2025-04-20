# Backend configuration for the 'dev' environment state

terraform {
  backend "s3" {
    bucket         = "terraform-state-cargo-connect" # Replace with the S3 bucket name to be used
    key            = "environments/dev/terraform.tfstate" # State path reflects the new structure
    region         = "us-east-1"                          # Must match the region used for the bucket/table
    dynamodb_table = "terraform-lock-cargo-connect"       # Replace with the DynamoDB table name to be used
    encrypt        = true
  }
}
