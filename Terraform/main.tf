# module "terraform_state" {
#   source      = "./modules/terraform-state"
#   bucket_name = "rasheed-tp-bk"
#   table_name  = "my-dynamodb-table"
# }


terraform {
  backend "s3" {
    bucket         = "rasheed-tp-bk"
    key            = "terraform.tfstate"  # Key path is just the state file name
    region         = "us-east-1"
    dynamodb_table = "my-dynamodb-table"
    encrypt        = true
  }
}
