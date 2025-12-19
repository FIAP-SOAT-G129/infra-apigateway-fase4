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
