variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "(Optional) AWS CLI profile to use"
  type        = string
  default     = ""
}

variable "availability_zones" {
  description = "List of availability zones to use (must contain at least 2)"
  type        = list(string)
  default     = []
}

variable "public_subnet_suffixes" {
  description = "Suffixes to append to subnet names for public subnets"
  type        = list(string)
  default     = ["a", "b"]
}

variable "private_subnet_suffixes" {
  description = "Suffixes to append to subnet names for private subnets"
  type        = list(string)
  default     = ["a", "b"]
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "project" {
  description = "Project name to add to resource tags"
  type        = string
  default     = ""
}
