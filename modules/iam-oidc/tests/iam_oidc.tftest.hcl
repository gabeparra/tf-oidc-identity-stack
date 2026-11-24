mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "valid_oidc_provider_claims_and_boundary" {
  command = plan

  variables {
    name_prefix     = "tf-oidc-test-kc"
    issuer_url      = "https://idp.example.com/realms/identity-lab/"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = ["0123456789abcdef0123456789abcdef01234567"]
    boundary_allowed_s3_arns = [
      "arn:aws:s3:::example-audit-logs",
      "arn:aws:s3:::example-audit-logs/*",
    ]
    federated_roles = {
      audit-reader = {
        description      = "Read-only audit role"
        audience         = "sts.amazonaws.com"
        allowed_subjects = ["service-account-internal-platform-api"]
        policy_statements = [
          {
            sid       = "ReadAuditObjects"
            actions   = ["s3:GetObject"]
            resources = ["arn:aws:s3:::example-audit-logs/*"]
          },
        ]
      }
    }
  }

  assert {
    condition     = local.issuer_condition_prefix == "idp.example.com/realms/identity-lab"
    error_message = "Issuer condition key prefix must strip https:// and trailing slash."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.this.url == "https://idp.example.com/realms/identity-lab/"
    error_message = "OIDC provider URL should match input."
  }

  assert {
    condition     = aws_iam_role.federated["audit-reader"].name == "tf-oidc-test-kc-audit-reader"
    error_message = "Federated role name should follow name_prefix-key convention."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.permission_boundary.statement :
      s.effect == "Deny" && contains(s.actions, "iam:DeleteRolePermissionsBoundary") && contains(s.actions, "iam:CreateAccessKey")
    ])
    error_message = "Permission boundary must explicitly deny IAM privilege escalation actions."
  }
}

run "rejects_non_https_issuer" {
  command = plan

  variables {
    name_prefix     = "tf-oidc-test-http"
    issuer_url      = "http://idp.example.com/realms/lab"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = ["0123456789abcdef0123456789abcdef01234567"]
    federated_roles = {
      reader = {
        description      = "Reader"
        audience         = "sts.amazonaws.com"
        allowed_subjects = ["repo:gabeparra/tf-oidc-identity-stack:ref:refs/heads/main"]
        policy_statements = [
          {
            sid       = "Read"
            actions   = ["s3:GetObject"]
            resources = ["arn:aws:s3:::example/*"]
          },
        ]
      }
    }
  }

  expect_failures = [
    var.issuer_url,
  ]
}

run "rejects_invalid_thumbprint" {
  command = plan

  variables {
    name_prefix     = "tf-oidc-test-thumb"
    issuer_url      = "https://idp.example.com/realms/lab"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = ["not-a-sha1"]
    federated_roles = {
      reader = {
        description      = "Reader"
        audience         = "sts.amazonaws.com"
        allowed_subjects = ["repo:gabeparra/tf-oidc-identity-stack:ref:refs/heads/main"]
        policy_statements = [
          {
            sid       = "Read"
            actions   = ["s3:GetObject"]
            resources = ["arn:aws:s3:::example/*"]
          },
        ]
      }
    }
  }

  expect_failures = [
    var.thumbprint_list,
  ]
}

run "rejects_wildcard_subject" {
  command = plan

  variables {
    name_prefix     = "tf-oidc-test-sub"
    issuer_url      = "https://idp.example.com/realms/lab"
    client_id_list  = ["sts.amazonaws.com"]
    thumbprint_list = ["0123456789abcdef0123456789abcdef01234567"]
    federated_roles = {
      overbroad = {
        description      = "Overbroad role that must be rejected"
        audience         = "sts.amazonaws.com"
        allowed_subjects = ["*"]
        policy_statements = [
          {
            sid       = "Read"
            actions   = ["s3:GetObject"]
            resources = ["arn:aws:s3:::example/*"]
          },
        ]
      }
    }
  }

  expect_failures = [
    var.federated_roles,
  ]
}
