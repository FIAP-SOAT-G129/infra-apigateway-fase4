variable "name" {
  description = "Base name for resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret for Lambda authorizer"
  type        = string
}

variable "tags" {
  description = "Default tags"
  type        = map(string)
  default     = {}
}

variable "alb_dns_name" {
  description = "DNS of the ALB created from Ingress"
  type        = string
}
