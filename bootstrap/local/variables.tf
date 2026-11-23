variable "aws_region" {
  description = "AWS region emulated by LocalStack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project slug."
  type        = string
  default     = "tf-oidc-identity"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "local"
}

variable "localstack_endpoint" {
  description = "HTTP endpoint for LocalStack."
  type        = string
  default     = "http://localhost:4566"
}
