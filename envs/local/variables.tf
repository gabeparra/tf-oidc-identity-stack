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

variable "keycloak_url" {
  description = "Local Keycloak base URL."
  type        = string
  default     = "http://localhost:8080"
}

variable "keycloak_admin_user" {
  description = "Keycloak bootstrap admin username."
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak bootstrap admin password. Supply via TF_VAR_keycloak_admin_password."
  type        = string
  sensitive   = true
}

variable "github_repository" {
  description = "GitHub owner/repo permitted to assume the CI plan role via GitHub OIDC."
  type        = string
  default     = "gabeparra/tf-oidc-identity-stack"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be formatted as owner/repo."
  }
}

variable "enable_upstream_broker_stub" {
  description = "Create a disabled placeholder upstream OIDC broker (Entra-style) in local Keycloak."
  type        = bool
  default     = true
}
