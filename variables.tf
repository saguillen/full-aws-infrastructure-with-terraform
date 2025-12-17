variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-2"
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

