output "s3_bucket_name" {
  description = "The name of the S3 bucket storing the Terraform state file"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table used for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
