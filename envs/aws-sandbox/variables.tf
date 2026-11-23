variable "aws_region" {
  description = "AWS region for the sandbox environment."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short project slug used as a prefix for resource names."
  type        = string
  default     = "tf-oidc-identity"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "sandbox"
}

variable "audit_bucket_name" {
  description = "Globally unique S3 bucket name for identity audit exports in the real AWS sandbox."
  type        = string
}

variable "github_repository" {
  description = "GitHub owner/repo allowed to assume the sandbox CI role over OIDC."
  type        = string
  default     = "gabeparra/tf-oidc-identity-stack"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be formatted as owner/repo."
  }
}

variable "enable_network" {
  description = "Optionally create the sandbox VPC (free with no NAT Gateway; disabled by default for IAM-only tests)."
  type        = bool
  default     = false
}

variable "allowed_https_cidrs" {
  description = "CIDR blocks permitted on TCP 443 when enable_network is true."
  type        = list(string)
  default     = ["10.30.0.0/16"]
}
