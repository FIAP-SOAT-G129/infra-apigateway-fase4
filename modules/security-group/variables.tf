variable "name" {
  type        = string
  description = "Base name for resources"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to deploy resources in"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block of the VPC"
}

variable "tags" {
  type    = map(string)
  default = {}
}
