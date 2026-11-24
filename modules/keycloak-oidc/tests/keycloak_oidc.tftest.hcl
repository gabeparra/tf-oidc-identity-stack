mock_provider "keycloak" {}

run "valid_keycloak_realm_clients_and_mappers" {
  command = plan

  variables {
    realm_name          = "identity-lab"
    display_name        = "Identity Lab SSO"
    keycloak_public_url = "https://idp.example.com/"
    ssl_required        = "external"
  }

  assert {
    condition     = keycloak_realm.this.access_token_lifespan == "15m"
    error_message = "Access tokens should stay short-lived (15m)."
  }

  assert {
    condition     = keycloak_realm.this.security_defenses[0].brute_force_detection[0].max_login_failures == 5
    error_message = "Brute-force protection must cap login failures at 5."
  }

  assert {
    condition     = keycloak_openid_client.confidential_app.pkce_code_challenge_method == "S256" && !keycloak_openid_client.confidential_app.implicit_flow_enabled && !keycloak_openid_client.confidential_app.direct_access_grants_enabled
    error_message = "Confidential client must enforce PKCE S256 and disable implicit/password grants."
  }

  assert {
    condition     = keycloak_openid_client.public_spa.access_type == "PUBLIC" && keycloak_openid_client.public_spa.pkce_code_challenge_method == "S256" && !keycloak_openid_client.public_spa.implicit_flow_enabled
    error_message = "Public SPA client must enforce PKCE S256 and disable implicit flow."
  }

  assert {
    condition     = keycloak_openid_audience_protocol_mapper.aws_sts.included_custom_audience == "sts.amazonaws.com"
    error_message = "AWS federation audience mapper must emit sts.amazonaws.com."
  }

  assert {
    condition     = length(keycloak_oidc_identity_provider.upstream_broker) == 0
    error_message = "Upstream broker should be omitted when upstream_broker is null."
  }

  assert {
    condition     = output.issuer_url == "https://idp.example.com/realms/identity-lab"
    error_message = "Issuer URL should trim trailing slash from keycloak_public_url."
  }
}

run "enables_upstream_broker_when_configured" {
  command = plan

  variables {
    realm_name          = "identity-lab"
    display_name        = "Identity Lab SSO"
    keycloak_public_url = "https://idp.example.com"
    upstream_broker = {
      alias             = "enterprise-oidc-stub"
      display_name      = "Enterprise OIDC Broker"
      enabled           = false
      authorization_url = "https://idp.example.invalid/oauth2/v2.0/authorize"
      token_url         = "https://idp.example.invalid/oauth2/v2.0/token"
      user_info_url     = "https://idp.example.invalid/oidc/userinfo"
      jwks_url          = "https://idp.example.invalid/discovery/v2.0/keys"
      issuer            = "https://idp.example.invalid/v2.0"
      client_id         = "placeholder-id"
      client_secret     = "placeholder-secret"
    }
  }

  assert {
    condition     = length(keycloak_oidc_identity_provider.upstream_broker) == 1
    error_message = "Upstream broker resource should be planned when upstream_broker is provided."
  }
}

run "rejects_invalid_realm_name" {
  command = plan

  variables {
    realm_name          = "Invalid_Realm"
    display_name        = "Bad Realm"
    keycloak_public_url = "https://idp.example.com"
  }

  expect_failures = [
    var.realm_name,
  ]
}

run "rejects_invalid_ssl_mode" {
  command = plan

  variables {
    realm_name          = "identity-lab"
    display_name        = "Identity Lab SSO"
    keycloak_public_url = "https://idp.example.com"
    ssl_required        = "optional"
  }

  expect_failures = [
    var.ssl_required,
  ]
}
