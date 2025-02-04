provider "aws" {
  region = "us-east-1"
}

# Create an S3 Bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "tp-bucket"

  lifecycle {
    prevent_destroy = true  # Prevent accidental deletion
  }

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "Dev"
  }
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption for the S3 bucket
resource "aws_s3_bucket_encryption" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# Create a DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform Lock Table"
    Environment = "Dev"
  }
}
