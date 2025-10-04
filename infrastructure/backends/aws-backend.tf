
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket" # Replace with your actual S3 bucket name
    key            = "path/to/your/terraform.tfstate"
    region         = "us-east-1" # Replace with your desired AWS region
    encrypt        = true
    dynamodb_table = "your-terraform-lock-table" # Optional, for state locking
  }

  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}