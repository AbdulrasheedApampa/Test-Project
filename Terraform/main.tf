module "terraform_state" {
  source      = "./modules/terraform-state"
  bucket_name = "rasheed-tp-bk"
  table_name  = "my-dynamodb-table"
}
