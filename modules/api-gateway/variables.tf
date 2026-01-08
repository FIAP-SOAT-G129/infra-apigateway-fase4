variable "name" {
  type        = string
  description = "Base name for resources"
}

variable "region" {
  description = "AWS region for API Gateway and Lambda"
  type        = string
}

variable "lb_port" {
  type        = number
  description = "Port used by the Load Balancer, Target Group and Listener"
  default     = 8080
}

variable "alb_dns_name" {
  type        = string
  description = "DNS of the ALB created from Ingress"
}

variable "alb_arn" {
  type        = string
  description = "ARN of the ALB created from Ingress"
}

variable "vpc_link_id" {
  type        = string
  description = "ID of the VPC Link created to connect API Gateway to the ALB"
}


variable "lambda_function_login_name" {
  type        = string
  description = "Name of the Lambda function to be integrated"
}

variable "lambda_function_login_arn" {
  type        = string
  description = "ARN of the Lambda function to be integrated"
}

variable "lambda_function_auth_name" {
  type        = string
  description = "Name of the Lambda function used for authorization"
}

variable "lambda_function_auth_arn" {
  type        = string
  description = "ARN of the Lambda function used as Authorizer"
}

variable "api_routes" {
  description = "Map of API routes with their configurations (method, path, auth_roles, etc)"
  type = map(object({
    method      = string
    path        = string
    alb_path    = string
    auth_roles  = list(string)
    path_params = list(string)
  }))
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the resources"
}


