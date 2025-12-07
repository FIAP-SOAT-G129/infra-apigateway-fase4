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

variable "catalog_port" {
  type        = number
  description = "Port for Catalog MS"
  default     = 8080
}

variable "order_port" {
  type        = number
  description = "Port for Order MS"
  default     = 8081
}

variable "payment_port" {
  type        = number
  description = "Port for Payment MS"
  default     = 8082
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
