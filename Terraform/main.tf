module "terraform_state" {
  source      = "./modules/terraform-state"
  bucket_name = "tp-bk"
  table_name  = "my-dynamodb-table"
}
