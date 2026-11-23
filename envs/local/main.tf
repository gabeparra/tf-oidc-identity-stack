# Bucket holding identity and access audit exports.
module "audit_logs_bucket" {
  source = "../../modules/s3-secure-bucket"

  bucket_name                        = "${local.name_prefix}-audit-logs"
  versioning_enabled                 = true
  force_destroy                      = true
  noncurrent_version_expiration_days = 365

  tags = {
    Purpose = "identity-audit-logs"
  }
}

# VPC with public and private subnets using for_each maps and locked-down default SG.
module "network" {
  source = "../../modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = "10.20.0.0/16"

  public_subnets = {
    az_a = { cidr_block = "10.20.1.0/24", availability_zone = "${var.aws_region}a" }
    az_b = { cidr_block = "10.20.2.0/24", availability_zone = "${var.aws_region}b" }
  }

  private_subnets = {
    az_a = { cidr_block = "10.20.11.0/24", availability_zone = "${var.aws_region}a" }
    az_b = { cidr_block = "10.20.12.0/24", availability_zone = "${var.aws_region}b" }
  }

  allowed_https_cidrs = ["10.20.0.0/16"]
}

# Declarative Keycloak realm, roles, groups, OIDC clients, token claim mappers,
# and a disabled placeholder upstream OIDC broker.
module "keycloak_oidc" {
  source = "../../modules/keycloak-oidc"

  realm_name          = "identity-lab"
  display_name        = "Identity Lab SSO"
  keycloak_public_url = var.keycloak_url
  ssl_required        = "none"

  realm_roles = ["platform-admin", "audit-reader", "app-user"]
  groups = {
    engineering    = ["platform-admin", "app-user"]
    security-audit = ["audit-reader", "app-user"]
  }

  aws_oidc_audience = "sts.amazonaws.com"

  upstream_broker = var.enable_upstream_broker_stub ? {
    alias             = "enterprise-oidc-stub"
    display_name      = "Enterprise OIDC Broker (Stub)"
    enabled           = false
    authorization_url = "https://idp.example.invalid/oauth2/v2.0/authorize"
    token_url         = "https://idp.example.invalid/oauth2/v2.0/token"
    user_info_url     = "https://idp.example.invalid/oidc/userinfo"
    jwks_url          = "https://idp.example.invalid/discovery/v2.0/keys"
    issuer            = "https://idp.example.invalid/v2.0"
    client_id         = "placeholder-broker-client-id"
    client_secret     = "placeholder-local-only-not-a-real-secret"
  } : null
}

# AWS IAM OIDC provider trusting the Keycloak realm issuer (HTTPS form required by AWS).
module "iam_oidc_keycloak" {
  source = "../../modules/iam-oidc"

  name_prefix    = "${local.name_prefix}-kc"
  issuer_url     = "https://idp.local.example/realms/${module.keycloak_oidc.realm_id}"
  client_id_list = ["sts.amazonaws.com", module.keycloak_oidc.confidential_client_id]
  # Placeholder SHA-1 thumbprint for LocalStack; real AWS uses the issuer's root CA thumbprint.
  thumbprint_list = ["0123456789abcdef0123456789abcdef01234567"]

  boundary_allowed_s3_arns = [
    module.audit_logs_bucket.bucket_arn,
    "${module.audit_logs_bucket.bucket_arn}/*",
  ]

  federated_roles = {
    audit-reader = {
      description      = "Read-only role for Keycloak security-audit subjects."
      audience         = "sts.amazonaws.com"
      allowed_subjects = ["service-account-internal-platform-api", "audit-reader:*"]
      policy_statements = [
        {
          sid       = "ListAuditBucket"
          actions   = ["s3:ListBucket"]
          resources = [module.audit_logs_bucket.bucket_arn]
        },
        {
          sid       = "ReadAuditObjects"
          actions   = ["s3:GetObject"]
          resources = ["${module.audit_logs_bucket.bucket_arn}/*"]
        },
      ]
    }
    audit-writer = {
      description      = "Write-only export role for identity audit log shippers."
      audience         = "sts.amazonaws.com"
      allowed_subjects = ["service-account-internal-platform-api"]
      policy_statements = [
        {
          sid       = "WriteAuditExports"
          actions   = ["s3:PutObject"]
          resources = ["${module.audit_logs_bucket.bucket_arn}/exports/*"]
        },
      ]
    }
  }
}

# Keyless GitHub Actions OIDC provider and tightly scoped CI plan role.
module "iam_oidc_github" {
  source = "../../modules/iam-oidc"

  name_prefix    = "${local.name_prefix}-gha"
  issuer_url     = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Standard GitHub Actions OIDC DigiCert/GitHub thumbprints.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  boundary_allowed_s3_arns = [
    "arn:aws:s3:::${local.name_prefix}-tfstate",
    "arn:aws:s3:::${local.name_prefix}-tfstate/*",
  ]

  federated_roles = {
    ci-plan = {
      description = "Keyless GitHub Actions role scoped to main branch and pull requests."
      audience    = "sts.amazonaws.com"
      allowed_subjects = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:pull_request",
      ]
      policy_statements = [
        {
          sid       = "ReadStateBucket"
          actions   = ["s3:ListBucket", "s3:GetObject"]
          resources = ["arn:aws:s3:::${local.name_prefix}-tfstate", "arn:aws:s3:::${local.name_prefix}-tfstate/*"]
        },
      ]
    }
  }
}
