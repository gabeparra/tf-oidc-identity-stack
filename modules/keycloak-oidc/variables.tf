variable "realm_name" {
  description = "Keycloak realm slug."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.realm_name))
    error_message = "realm_name must be 3 to 40 lowercase letters, digits, or hyphens."
  }
}

variable "display_name" {
  description = "Human-readable display name shown on the login screen."
  type        = string
}

variable "keycloak_public_url" {
  description = "Base URL of the Keycloak server used to compute the OIDC issuer URL output."
  type        = string
}

variable "ssl_required" {
  description = "Keycloak SSL requirement ('external' or 'all' in production, 'none' only for local HTTP dev)."
  type        = string
  default     = "external"

  validation {
    condition     = contains(["all", "external", "none"], var.ssl_required)
    error_message = "ssl_required must be one of: all, external, none."
  }
}

variable "realm_roles" {
  description = "List of realm-level roles to manage declaratively."
  type        = list(string)
  default     = ["platform-admin", "audit-reader", "app-user"]
}

variable "groups" {
  description = "Map of group names to the list of realm roles assigned to each group."
  type        = map(list(string))
  default = {
    engineering    = ["platform-admin", "app-user"]
    security-audit = ["audit-reader", "app-user"]
  }
}

variable "confidential_client_id" {
  description = "Client ID for the confidential backend OIDC application."
  type        = string
  default     = "internal-platform-api"
}

variable "confidential_redirect_uris" {
  description = "Exact redirect URIs allowed for the confidential OIDC client."
  type        = list(string)
  default     = ["http://localhost:3000/api/auth/callback/keycloak"]
}

variable "public_client_id" {
  description = "Client ID for the PKCE public SPA OIDC application."
  type        = string
  default     = "staff-portal-spa"
}

variable "public_redirect_uris" {
  description = "Exact redirect URIs allowed for the PKCE public client."
  type        = list(string)
  default     = ["http://localhost:5173/auth/callback"]
}

variable "aws_oidc_audience" {
  description = "Audience value injected into tokens for AWS STS web identity federation."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "upstream_broker" {
  description = "Optional upstream OIDC identity provider configuration (for example, Microsoft Entra ID)."
  type = object({
    alias             = string
    display_name      = string
    enabled           = bool
    authorization_url = string
    token_url         = string
    user_info_url     = string
    jwks_url          = string
    issuer            = string
    client_id         = string
    client_secret     = string
  })
  default   = null
  sensitive = true
}
