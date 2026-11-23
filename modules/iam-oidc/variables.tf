variable "name_prefix" {
  description = "Prefix applied to IAM role and policy names."
  type        = string
}

variable "issuer_url" {
  description = "HTTPS issuer URL of the OIDC provider (for example, a Keycloak realm URL or GitHub Actions)."
  type        = string

  validation {
    condition     = startswith(var.issuer_url, "https://")
    error_message = "issuer_url must start with https:// (AWS IAM OIDC providers require TLS)."
  }
}

variable "client_id_list" {
  description = "Allowed OIDC audience (aud) values for this provider."
  type        = list(string)

  validation {
    condition     = length(var.client_id_list) > 0
    error_message = "client_id_list must contain at least one audience value."
  }
}

variable "thumbprint_list" {
  description = "SHA-1 server certificate thumbprints (40 hex characters each) for the OIDC issuer."
  type        = list(string)

  validation {
    condition     = length(var.thumbprint_list) > 0 && alltrue([for t in var.thumbprint_list : can(regex("^[0-9a-fA-F]{40}$", t))])
    error_message = "thumbprint_list must contain one or more 40-character hex SHA-1 thumbprints."
  }
}

variable "boundary_allowed_s3_arns" {
  description = "Bucket and object ARNs permitted by the IAM permission boundary."
  type        = list(string)
  default     = []
}

variable "federated_roles" {
  description = "Map of least-privilege IAM roles assumable via sts:AssumeRoleWithWebIdentity."
  type = map(object({
    description          = string
    audience             = string
    allowed_subjects     = list(string)
    max_session_duration = optional(number, 3600)
    policy_statements = list(object({
      sid       = string
      effect    = optional(string, "Allow")
      actions   = list(string)
      resources = list(string)
    }))
  }))

  validation {
    condition = alltrue([
      for r in values(var.federated_roles) :
      length(r.allowed_subjects) > 0 && !contains(r.allowed_subjects, "*")
    ])
    error_message = "Each federated role must declare explicit allowed_subjects and never use a bare '*' wildcard."
  }
}

variable "tags" {
  description = "Additional tags applied to IAM resources."
  type        = map(string)
  default     = {}
}
