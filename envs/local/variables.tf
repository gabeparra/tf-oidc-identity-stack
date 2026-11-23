variable "aws_region" {
  description = "AWS region emulated by LocalStack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project slug used as a prefix for resource names."
  type        = string
  default     = "tf-oidc-identity"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "project_name must be 3 to 32 lowercase letters, digits, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "sandbox", "dev"], var.environment)
    error_message = "environment must be one of: local, sandbox, dev."
  }
}

variable "localstack_endpoint" {
  description = "HTTP endpoint for the local AWS emulator."
  type        = string
  default     = "http://localhost:4566"
}
