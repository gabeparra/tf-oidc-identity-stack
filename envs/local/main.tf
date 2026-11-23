# Bucket prepared for Milestone 2 remote state migration.
module "tfstate_bucket" {
  source = "../../modules/s3-secure-bucket"

  bucket_name                        = "${local.name_prefix}-tfstate"
  versioning_enabled                 = true
  force_destroy                      = true
  noncurrent_version_expiration_days = 90

  tags = {
    Purpose = "terraform-state"
  }
}

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

# Least-privilege IAM role allowed to list and read only the audit-logs bucket.
# In Milestone 2 we replace this local trust policy with an OIDC federated trust policy.
data "aws_iam_policy_document" "audit_reader_trust" {
  statement {
    sid     = "AllowLocalAccountAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::000000000000:root"]
    }
  }
}

resource "aws_iam_role" "audit_reader" {
  name               = "${local.name_prefix}-audit-reader"
  assume_role_policy = data.aws_iam_policy_document.audit_reader_trust.json
  description        = "Read-only role scoped to the identity audit-logs S3 bucket."
}

data "aws_iam_policy_document" "audit_reader_permissions" {
  statement {
    sid       = "ListAuditBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.audit_logs_bucket.bucket_arn]
  }

  statement {
    sid       = "ReadAuditObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.audit_logs_bucket.bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "audit_reader" {
  name   = "${local.name_prefix}-audit-reader-s3"
  role   = aws_iam_role.audit_reader.id
  policy = data.aws_iam_policy_document.audit_reader_permissions.json
}
