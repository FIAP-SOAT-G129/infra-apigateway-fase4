output "lambda_login_function_name" {
  description = "Name of the Login Lambda function"
  value       = module.lambda_login.function_name
}

output "lambda_auth_function_name" {
  description = "Name of the Auth Lambda function"
  value       = module.lambda_auth.function_name
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = module.api_gateway.invoke_url
}

# Debug outputs
output "api_gateway_id" {
  description = "API Gateway ID for debugging"
  value       = module.api_gateway.api_gateway_id
}

output "alb_dns_name" {
  description = "ALB DNS name used in integrations (for debugging)"
  value       = module.api_gateway.alb_dns_name
}

output "alb_dns_from_datasource" {
  description = "ALB DNS name from datasource (for debugging)"
  value       = data.aws_lb.fastfood_alb.dns_name
}

output "alb_arn" {
  description = "ALB ARN from datasource (for debugging)"
  value       = data.aws_lb.fastfood_alb.arn
}

output "alb_scheme" {
  description = "ALB scheme (internet-facing/internal) for debugging"
  value       = data.aws_lb.fastfood_alb.internal ? "internal" : "internet-facing"
}
