data "aws_caller_identity" "current" {}

data "aws_lb" "internal_nlb" {
  name = "fastfood-nlb"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/zips/${var.function_name}.zip"
}
