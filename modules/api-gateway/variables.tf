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

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the resources"
}
