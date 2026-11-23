resource "keycloak_realm" "this" {
  realm        = var.realm_name
  enabled      = true
  display_name = var.display_name
  ssl_required = var.ssl_required

  access_token_lifespan    = "15m"
  sso_session_idle_timeout = "30m"
  sso_session_max_lifespan = "8h"

  security_defenses {
    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 5
      wait_increment_seconds           = 60
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
      max_failure_wait_seconds         = 900
      failure_reset_time_seconds       = 43200
    }
  }
}

resource "keycloak_role" "realm_roles" {
  for_each = toset(var.realm_roles)

  realm_id    = keycloak_realm.this.id
  name        = each.key
  description = "Realm role managed by Terraform."
}

resource "keycloak_group" "groups" {
  for_each = var.groups

  realm_id = keycloak_realm.this.id
  name     = each.key
}

resource "keycloak_group_roles" "group_roles" {
  for_each = var.groups

  realm_id = keycloak_realm.this.id
  group_id = keycloak_group.groups[each.key].id
  role_ids = [for r in each.value : keycloak_role.realm_roles[r].id]
}

resource "keycloak_openid_client_scope" "aws_federation" {
  realm_id               = keycloak_realm.this.id
  name                   = "aws-federation"
  description            = "Adds AWS STS audience, groups, and realm roles claims for IAM OIDC federation."
  include_in_token_scope = true
}

resource "keycloak_openid_audience_protocol_mapper" "aws_sts" {
  realm_id                 = keycloak_realm.this.id
  client_scope_id          = keycloak_openid_client_scope.aws_federation.id
  name                     = "aws-sts-audience"
  included_custom_audience = var.aws_oidc_audience
  add_to_id_token          = true
  add_to_access_token      = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id            = keycloak_realm.this.id
  client_scope_id     = keycloak_openid_client_scope.aws_federation.id
  name                = "groups-claim"
  claim_name          = "groups"
  full_path           = false
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

resource "keycloak_openid_user_realm_role_protocol_mapper" "roles" {
  realm_id            = keycloak_realm.this.id
  client_scope_id     = keycloak_openid_client_scope.aws_federation.id
  name                = "realm-roles-claim"
  claim_name          = "roles"
  multivalued         = true
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

resource "keycloak_openid_client" "confidential_app" {
  realm_id                     = keycloak_realm.this.id
  client_id                    = var.confidential_client_id
  name                         = "Internal Platform API (Confidential)"
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  service_accounts_enabled     = true
  pkce_code_challenge_method   = "S256"
  valid_redirect_uris          = var.confidential_redirect_uris
  web_origins                  = ["+"]
}

resource "keycloak_client_scope_assignments" "confidential_defaults" {
  realm_id  = keycloak_realm.this.id
  client_id = keycloak_openid_client.confidential_app.id
  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.aws_federation.name,
  ]
  optional_scopes = []
}

resource "keycloak_openid_client" "public_spa" {
  realm_id                     = keycloak_realm.this.id
  client_id                    = var.public_client_id
  name                         = "Staff Portal SPA (PKCE Public)"
  enabled                      = true
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = false
  pkce_code_challenge_method   = "S256"
  valid_redirect_uris          = var.public_redirect_uris
  web_origins                  = ["+"]
}

resource "keycloak_oidc_identity_provider" "upstream_broker" {
  count = var.upstream_broker != null ? 1 : 0

  realm             = keycloak_realm.this.id
  alias             = var.upstream_broker.alias
  display_name      = var.upstream_broker.display_name
  enabled           = var.upstream_broker.enabled
  authorization_url = var.upstream_broker.authorization_url
  token_url         = var.upstream_broker.token_url
  user_info_url     = var.upstream_broker.user_info_url
  jwks_url          = var.upstream_broker.jwks_url
  issuer            = var.upstream_broker.issuer
  client_id         = var.upstream_broker.client_id
  client_secret     = var.upstream_broker.client_secret
  default_scopes    = "openid profile email"
  sync_mode         = "IMPORT"
  trust_email       = true
}
