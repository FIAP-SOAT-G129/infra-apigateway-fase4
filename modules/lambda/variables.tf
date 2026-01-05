variable "function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "handler" {
  type        = string
  default     = "index.handler"
  description = "Lambda handler"
}

variable "runtime" {
  type        = string
  default     = "nodejs18.x"
  description = "Lambda runtime"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the resources"
}

variable "lb_port" {
  type        = number
  description = "Port used by the Load Balancer, Target Group and Listener"
  default     = 8080
}

variable "source_dir" {
  type        = string
  description = "Path to the source directory of the Lambda code"
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function in seconds"
  type        = number
  default     = 300
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the EKS worker nodes"
}

variable "security_groups" {
  type        = list(string)
  description = "List of security group IDs to associate with the Load Balancer"
}

variable "jwt_secret_name" {
  type        = string
  description = "Name of the JWT secret in Secrets Manager"
  default     = ""
}
variable "region" {
  description = "AWS region for API Gateway and Lambda"
  type        = string
}

variable "route_roles" {
  description = "Route-to-role mapping configuration (map of route patterns to required roles)"
  type        = map(string)
  default     = {}
}
