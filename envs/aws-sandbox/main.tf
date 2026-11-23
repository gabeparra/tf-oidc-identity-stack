# Reuses the exact same modules as envs/local against real AWS.
# IAM OIDC providers, roles, and policies are free on AWS; S3 storage is near-$0
# for small sandbox objects and force_destroy stays false by default.

module "audit_logs_bucket" {
  source = "../../modules/s3-secure-bucket"

  bucket_name                        = var.audit_bucket_name
  versioning_enabled                 = true
  force_destroy                      = false
  noncurrent_version_expiration_days = 90

  tags = {
    Purpose = "identity-audit-logs"
  }
}

module "network" {
  count  = var.enable_network ? 1 : 0
  source = "../../modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = "10.30.0.0/16"

  public_subnets = {
    az_a = { cidr_block = "10.30.1.0/24", availability_zone = "${var.aws_region}a" }
    az_b = { cidr_block = "10.30.2.0/24", availability_zone = "${var.aws_region}b" }
  }

  private_subnets = {
    az_a = { cidr_block = "10.30.11.0/24", availability_zone = "${var.aws_region}a" }
    az_b = { cidr_block = "10.30.12.0/24", availability_zone = "${var.aws_region}b" }
  }

  allowed_https_cidrs = var.allowed_https_cidrs
}

module "iam_oidc_github" {
  source = "../../modules/iam-oidc"

  name_prefix    = "${local.name_prefix}-gha"
  issuer_url     = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  boundary_allowed_s3_arns = [
    module.audit_logs_bucket.bucket_arn,
    "${module.audit_logs_bucket.bucket_arn}/*",
  ]

  federated_roles = {
    audit-reader = {
      description = "Keyless GitHub Actions role scoped to reading the sandbox audit bucket."
      audience    = "sts.amazonaws.com"
      allowed_subjects = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:pull_request",
      ]
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
  }
}
