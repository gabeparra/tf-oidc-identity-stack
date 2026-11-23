output "realm_id" {
  description = "Keycloak realm ID."
  value       = keycloak_realm.this.id
}

output "issuer_url" {
  description = "OIDC issuer URL for this Keycloak realm."
  value       = "${trimsuffix(var.keycloak_public_url, "/")}/realms/${keycloak_realm.this.realm}"
}

output "confidential_client_id" {
  description = "Client ID of the confidential OIDC application."
  value       = keycloak_openid_client.confidential_app.client_id
}

output "public_client_id" {
  description = "Client ID of the public PKCE SPA client."
  value       = keycloak_openid_client.public_spa.client_id
}

output "role_names" {
  description = "Sorted list of managed realm roles."
  value       = sort(keys(keycloak_role.realm_roles))
}

output "group_names" {
  description = "Sorted list of managed Keycloak groups."
  value       = sort(keys(keycloak_group.groups))
}
