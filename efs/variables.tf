variable "name" {
  type        = string
  default = "k8tre-dev"
  description = "Name used for resources"
}

variable "vpc_id" {
  type        = string
  default = "vpc-01a1322bb1f471477"
  description = "VPC ID"
}

variable "subnets" {
  type        = list(string)
  default = [
    "subnet-004a8e53e43ee8c2b",
    "subnet-020de90e7fe3d9994",
    "subnet-050b5b2e278f0f209",
    "subnet-04f8cac27f3b39979"
  ]
  description = "List of subnet IDs"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS encryption key ARN"
  default     = null
}
