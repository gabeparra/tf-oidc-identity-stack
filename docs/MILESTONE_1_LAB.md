# Milestone 1 Lab: Terraform Foundations, State, and Modules

This lab walks through the core Terraform workflow against a local AWS emulator (LocalStack) so you can break things, inspect state, and verify behavior with zero cloud cost.

## Layout and Why It Is Split This Way

- `modules/s3-secure-bucket/`: Reusable child module that enforces our S3 baseline (public access blocked, BucketOwnerEnforced ownership, versioning, AES256 encryption with bucket keys, and lifecycle cleanup). Child modules set open minimum provider constraints (`>= 5.80.0`) and never commit a `.terraform.lock.hcl` file.
- `envs/local/`: Root module for the local environment. Root modules configure `provider` blocks, pin narrower provider constraints (`~> 5.80`), hold state, and commit `.terraform.lock.hcl` so every machine and CI runner downloads the exact same provider binaries.
- `providers.tf`: Uses `default_tags` so `Project`, `Environment`, and `ManagedBy` apply to every taggable resource without repeating them.
- `main.tf`: Builds IAM policies with `data "aws_iam_policy_document"` instead of raw JSON heredocs, which gives static validation and implicit dependency tracking from `module.audit_logs_bucket.bucket_arn`.

## Drill 1: Core Loop and State Inspection

Start LocalStack and run the standard plan-then-apply workflow:

```bash
make up
make init
make plan
make apply
```

Inspect what Terraform recorded in local state (`envs/local/terraform.tfstate`):

```bash
make state
terraform -chdir=envs/local state show aws_iam_role.audit_reader
terraform -chdir=envs/local output
make aws-ls
```

Key check: Notice how `terraform plan -out=tfplan` freezes the exact execution plan so `terraform apply tfplan` cannot apply a different change set than the one you reviewed.

## Drill 2: Out-of-Band Drift Detection and Reconciliation

Simulate someone clicking around in the AWS console and weakening public access controls on the audit bucket:

```bash
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
  aws --endpoint-url=http://localhost:4566 s3api put-public-access-block \
  --bucket tf-oidc-identity-local-audit-logs \
  --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Now run a plan:

```bash
terraform -chdir=envs/local plan
```

Terraform refreshes live state from the API, detects `block_public_acls: false -> true`, and proposes an in-place update (`~`). Run `make plan && make apply` to bring the bucket back into compliance.

## Drill 3: Zero-Downtime Refactor with `moved {}`

If you rename a resource or move it into a module in HCL without telling Terraform, `terraform plan` schedules a destroy (`-`) followed by a create (`+`).

Test it safely on `aws_iam_role.audit_reader`:
1. Rename `aws_iam_role.audit_reader` to `aws_iam_role.identity_audit_reader` (and update references in `main.tf` and `outputs.tf`).
2. Run `terraform -chdir=envs/local plan` first and observe the destroy + create plan. Do NOT apply.
3. Add a `moved` block:
   ```hcl
   moved {
     from = aws_iam_role.audit_reader
     to   = aws_iam_role.identity_audit_reader
   }
   ```
4. Re-run `terraform -chdir=envs/local plan`. Terraform reports the address move cleanly with zero destruction. Revert the rename afterward (or keep the original name for Milestone 2).

## Drill 4: Adopting a Pre-Existing Resource (`import {}`)

Simulate bringing an existing S3 bucket under Terraform management:

```bash
AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
  aws --endpoint-url=http://localhost:4566 s3 mb s3://tf-oidc-identity-local-legacy
```

Add a temporary `import` block plus a matching `aws_s3_bucket` resource in a scratch `.tf` file inside `envs/local/`:

```hcl
import {
  to = aws_s3_bucket.legacy
  id = "tf-oidc-identity-local-legacy"
}

resource "aws_s3_bucket" "legacy" {
  bucket = "tf-oidc-identity-local-legacy"
}
```

Run `terraform -chdir=envs/local plan`. Terraform shows `1 to import` rather than creating a duplicate bucket. After applying and verifying `state list`, remove the `import` block (imports are one-time migrations) and clean up the scratch resource before Milestone 2.
