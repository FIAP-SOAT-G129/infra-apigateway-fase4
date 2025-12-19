terraform {
  backend "s3" {
    bucket = "fastfood-tf-states"
    key    = "infra/lambda/terraform.tfstate"
    region = "us-east-1"
  }
}