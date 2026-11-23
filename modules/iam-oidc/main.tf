locals {
  # AWS IAM OIDC condition keys omit the https:// scheme and any trailing slash.
  issuer_condition_prefix = trim(trimprefix(var.issuer_url, "https://"), "/")
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = var.issuer_url
  client_id_list  = var.client_id_list
  thumbprint_list = var.thumbprint_list
  tags            = var.tags
}

# Permission boundary caps the effective permissions of every federated role
# created by this module and explicitly denies IAM privilege escalation paths.
data "aws_iam_policy_document" "permission_boundary" {
  statement {
    sid       = "AllowCallerIdentityCheck"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.boundary_allowed_s3_arns) > 0 ? [1] : []

    content {
      sid       = "AllowScopedS3Access"
      effect    = "Allow"
      actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
      resources = var.boundary_allowed_s3_arns
    }
  }

  statement {
    sid    = "DenyPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateAccessKey",
      "iam:CreateUser",
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "permission_boundary" {
  name        = "${var.name_prefix}-oidc-boundary"
  description = "Permission boundary capping federated OIDC roles and blocking IAM escalation."
  policy      = data.aws_iam_policy_document.permission_boundary.json
  tags        = var.tags
}

data "aws_iam_policy_document" "role_trust" {
  for_each = var.federated_roles

  statement {
    sid     = "AllowFederatedOidcAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer_condition_prefix}:aud"
      values   = [each.value.audience]
    }

    condition {
      test     = "StringLike"
      variable = "${local.issuer_condition_prefix}:sub"
      values   = each.value.allowed_subjects
    }
  }
}

resource "aws_iam_role" "federated" {
  for_each = var.federated_roles

  name                 = "${var.name_prefix}-${each.key}"
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.role_trust[each.key].json
  permissions_boundary = aws_iam_policy.permission_boundary.arn
  max_session_duration = each.value.max_session_duration
  tags                 = var.tags
}

data "aws_iam_policy_document" "role_permissions" {
  for_each = var.federated_roles

  dynamic "statement" {
    for_each = each.value.policy_statements

    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "role_permissions" {
  for_each = var.federated_roles

  name        = "${var.name_prefix}-${each.key}-policy"
  description = "Least-privilege policy attached to federated role ${each.key}."
  policy      = data.aws_iam_policy_document.role_permissions[each.key].json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "role_permissions" {
  for_each = var.federated_roles

  role       = aws_iam_role.federated[each.key].name
  policy_arn = aws_iam_policy.role_permissions[each.key].arn
}
