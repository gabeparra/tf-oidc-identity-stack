mock_provider "aws" {}

run "default_secure_bucket_settings" {
  command = plan

  variables {
    bucket_name = "tf-oidc-test-audit-logs"
  }

  assert {
    condition     = aws_s3_bucket.this.bucket == "tf-oidc-test-audit-logs"
    error_message = "Bucket name should match input."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false to protect non-sandbox buckets."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.this.block_public_acls &&
      aws_s3_bucket_public_access_block.this.block_public_policy &&
      aws_s3_bucket_public_access_block.this.ignore_public_acls &&
      aws_s3_bucket_public_access_block.this.restrict_public_buckets
    )
    error_message = "All four S3 public access block flags must be true."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "Bucket ownership must disable ACLs via BucketOwnerEnforced."
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must default to Enabled."
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    error_message = "Default encryption must use free SSE-S3 (AES256) when kms_key_arn is null."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 1
    error_message = "Lifecycle rule must be created when versioning is enabled."
  }
}

run "kms_encryption_mode" {
  command = plan

  variables {
    bucket_name = "tf-oidc-test-kms-bucket"
    kms_key_arn = "arn:aws:kms:us-east-1:111122223333:key/12345678-1234-1234-1234-1234567890ab"
  }

  assert {
    condition     = one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "Setting kms_key_arn must switch SSE algorithm to aws:kms."
  }
}

run "versioning_disabled_skips_lifecycle" {
  command = plan

  variables {
    bucket_name        = "tf-oidc-test-no-versioning"
    versioning_enabled = false
  }

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended"
    error_message = "Disabling versioning must set status to Suspended."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 0
    error_message = "Lifecycle rule should be omitted when versioning is disabled."
  }
}

run "rejects_invalid_bucket_name" {
  command = plan

  variables {
    bucket_name = "Invalid_Bucket_Name"
  }

  expect_failures = [
    var.bucket_name,
  ]
}

run "rejects_invalid_expiration_days" {
  command = plan

  variables {
    bucket_name                        = "tf-oidc-test-valid-name"
    noncurrent_version_expiration_days = 0
  }

  expect_failures = [
    var.noncurrent_version_expiration_days,
  ]
}
