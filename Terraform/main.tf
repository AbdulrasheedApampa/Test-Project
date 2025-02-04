module "terraform_state" {
  source      = "./modules/terraform-state"
  bucket_name = "tp-bucket"
  table_name  = "my-dynamodb-table"
}
