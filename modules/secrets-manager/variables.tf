variable "name" {
  type        = string
  description = "Base name for resources"
}

variable "jwt_secret" {
  type        = string
  description = "JWT secret for Lambda authorizer"
}