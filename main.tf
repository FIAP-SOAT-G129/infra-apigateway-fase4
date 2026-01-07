locals {
  route_roles = {
    "GET:/v1/orders"      = "customer"
    "GET:/v1/products/*"  = "employee"
    "POST:/v1/categories" = "employee"
    "GET:/v1/orders/*"    = "customer"
  }
}

module "security_group" {
  source         = "./modules/security-group"
  name           = var.name
  vpc_id         = data.terraform_remote_state.foundation.outputs.vpc_id
  vpc_cidr_block = data.terraform_remote_state.foundation.outputs.vpc_cidr_block
  tags           = var.tags
}

module "lambda_auth" {
  source          = "./modules/lambda"
  function_name   = "${var.name}-auth-lambda"
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  subnet_ids      = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  security_groups = [module.security_group.lambda_sg_id]
  source_dir      = "${path.root}/lambdas/auth_lambda"
  jwt_secret_name = module.secrets.secret_name
  route_roles     = local.route_roles
  tags            = var.tags
  region          = var.region
  alb_dns_name    = data.aws_lb.fastfood_alb.dns_name
}

module "lambda_login" {
  source          = "./modules/lambda"
  function_name   = "${var.name}-login-lambda"
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  subnet_ids      = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  security_groups = [module.security_group.lambda_sg_id]
  source_dir      = "${path.root}/lambdas/login_lambda"
  jwt_secret_name = module.secrets.secret_name
  tags            = var.tags
  region          = var.region
  alb_dns_name    = data.aws_lb.fastfood_alb.dns_name
}

module "vpc_link" {
  source     = "./modules/vpc-link"
  name       = var.name
  subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids
  tags       = var.tags

}

module "api_gateway" {
  source = "./modules/api-gateway"
  name   = var.name
  region = var.region

  alb_dns_name = data.aws_lb.fastfood_alb.dns_name
  alb_arn      = data.aws_lb.fastfood_alb.arn
  vpc_link_id  = module.vpc_link.id

  lambda_function_login_name = module.lambda_login.function_name
  lambda_function_login_arn  = module.lambda_login.function_arn
  lambda_function_auth_name  = module.lambda_auth.function_name
  lambda_function_auth_arn   = module.lambda_auth.function_arn

  route_roles = local.route_roles
  tags        = var.tags
}


module "secrets" {
  source     = "./modules/secrets-manager"
  name       = var.name
  jwt_secret = var.jwt_secret
}
