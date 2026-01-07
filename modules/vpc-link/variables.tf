variable "name" {
  type        = string
  description = "Base name for resources"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the VPC Link"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the resources"
}

