output "invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.dev.stage_name}"
}

# Debug outputs
output "api_gateway_id" {
  description = "API Gateway ID for debugging"
  value       = aws_api_gateway_rest_api.this.id
}

output "alb_dns_name" {
  description = "ALB DNS name used in integrations (for debugging)"
  value       = var.alb_dns_name
}

output "deployment_id" {
  description = "Deployment ID for debugging"
  value       = aws_api_gateway_deployment.this.id
}

output "stage_name" {
  description = "Stage name for debugging"
  value       = aws_api_gateway_stage.dev.stage_name
}
