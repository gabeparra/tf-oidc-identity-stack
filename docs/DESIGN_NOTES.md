# Design Notes and Technical Walkthrough

Reference for the reasoning behind each Terraform and cloud-identity design decision in `tf-oidc-identity-stack`.

## 1. Remote State, Locking, and Bootstrap Separation

- **Why `bootstrap/local/` is separate from `envs/local/`:** The S3 bucket storing Terraform state should never live inside the same state file it holds. Separating bootstrap keeps `terraform destroy` on an environment from attempting to delete its own state backend.
- **How state locking works:** `envs/local/backend.tf` uses Terraform 1.10+ native S3 lockfiles (`use_lockfile = true`). Terraform acquires a lock by writing a `.tflock` object with `If-None-Match: *`; S3 rejects concurrent writers with `412 PreconditionFailed`. Older Terraform codebases used a DynamoDB table (`dynamodb_table` with string partition key `LockID`). Both solve the same concurrency hazard: two engineers or CI jobs writing state at the same time and corrupting it.
- **Recovering a stuck lock:** First verify no CI run or teammate is actively applying, then run `terraform force-unlock <LOCK_ID>`.
- **Migrating state:** When moving from local state to S3 (Milestone 1 to Milestone 2), `terraform init -migrate-state` copies the state file into the new backend. Use `terraform state rm` before applying if a resource (like the state bucket) is moving out of that root module's ownership so Terraform does not destroy it.

## 2. Sensitive Values in State

Marking a variable or output `sensitive = true` hides its value in terminal logs and plan diffs, **not** inside `terraform.tfstate`. Any secret created or passed into a resource (such as an OIDC broker client secret) still lands in state in plaintext. That is why state is never committed to git, stored in a private encrypted S3 bucket (`encrypt = true`, `PublicAccessBlock` enabled), and scoped by IAM least privilege.

## 3. Module Boundaries and Provider Constraints

- **Child modules (`modules/*`):** Declare open minimum version constraints (`version = ">= 5.80.0"`) and never contain `provider` blocks or `.terraform.lock.hcl` files. This keeps modules composable across multiple environments.
- **Root modules (`bootstrap/local`, `envs/local`, `envs/aws-sandbox`):** Configure `provider` blocks (including `default_tags`), pin narrower provider constraints (`~> 5.80`), hold state, and commit `.terraform.lock.hcl` so local laptops and CI runners verify identical provider checksums.

## 4. `for_each` Maps vs `count` Lists

- `modules/network` uses `for_each = var.public_subnets` (map keyed by `az_a`, `az_b`) and `modules/iam-oidc` uses `for_each = var.federated_roles` (map keyed by `audit-reader`, `audit-writer`).
- With `count`, removing element `[0]` shifts `[1]` into `[0]`, causing Terraform to destroy and recreate unaffected subnets or IAM roles. Map keys give every instance a stable state address (`aws_subnet.public["az_a"]`).
- `count` is reserved strictly for binary feature toggles (`count = var.versioning_enabled ? 1 : 0`, `count = var.upstream_broker != null ? 1 : 0`).

## 5. Safe Refactoring, Imports, and Replacements

- **`moved {}` block:** Renaming a resource or moving it into a module without a `moved` block plans a destroy + create. Adding a `moved` block updates the state address in place with zero downtime and can be code-reviewed in git.
- **`import {}` block:** Brings an existing cloud resource created outside Terraform under management declaratively during `plan`/`apply`, replacing imperative `terraform import` CLI commands in team workflows.
- **Forcing recreation:** Prefer `terraform apply -replace=<address>` over the deprecated `terraform taint` command when a single unhealthy resource must be rebuilt.
- **Lifecycle rules:** `modules/network` uses `create_before_destroy = true` on `aws_security_group.identity_proxy` so security group updates do not fail with `DependencyViolation` while attached to ENIs.

## 6. OIDC Federation and Least-Privilege IAM

- **Why OIDC over static keys:** Static IAM user access keys leak, go stale, and require manual rotation. OIDC federation (`sts:AssumeRoleWithWebIdentity`) issues short-lived STS credentials tied to a signed JWT from Keycloak or GitHub Actions.
- **Preventing confused-deputy attacks:** Trust policies in `modules/iam-oidc` require BOTH `StringEquals` on `<issuer>:aud` and `StringLike` on `<issuer>:sub`. The module's input validation rejects any bare `*` subject wildcard at plan time, verified by `modules/iam-oidc/tests/iam_oidc.tftest.hcl`.
- **Permission boundaries:** Every federated role attaches `aws_iam_policy.permission_boundary`. Even if a role's identity policy were accidentally widened later, effective permissions cannot exceed the boundary, and IAM privilege-escalation actions (`iam:CreateAccessKey`, `iam:PutRolePermissionsBoundary`, `iam:DeleteRolePermissionsBoundary`, `iam:AttachRolePolicy`) are explicitly denied.
- **Keycloak token design:** `modules/keycloak-oidc` enforces PKCE (`S256`) on both confidential and public SPA clients, disables legacy implicit and resource-owner password grants, sets a 15-minute access token lifespan with brute-force detection, and uses a dedicated `aws-federation` client scope to emit `sts.amazonaws.com` audience plus `groups` and `roles` claims.

## 7. Testing, Static Analysis, and Drift Detection

- **Fast contract tests (`terraform test`):** Every module has a `tests/*.tftest.hcl` suite using `mock_provider` to verify defaults, conditional branches (KMS vs AES256, optional upstream broker), and negative security validations (`expect_failures`).
- **Static guardrails:** `terraform fmt -check`, `terraform validate`, `tflint --recursive` (with `terraform` recommended preset + `aws` ruleset), and `trivy config --severity HIGH,CRITICAL --exit-code 1 .`.
- **Drift detection:** `terraform plan -detailed-exitcode` returns `0` (no diff), `1` (error), or `2` (drift detected). Both `scripts/verify-local-e2e.sh` and `.github/workflows/drift-detection.yml` use this exit-code contract. In local CI we intentionally mutate the audit bucket's public-access block via AWS CLI, assert exit code `2`, reconcile via `apply`, and assert exit code `0`.

## 8. Cost and Practical Tradeoffs

- **SSE-S3 (`AES256`) vs SSE-KMS:** `modules/s3-secure-bucket` defaults to free SSE-S3 with bucket keys and switches to `aws:kms` when `kms_key_arn` is supplied (KMS CMKs cost $1/key/month plus request charges on AWS).
- **No NAT Gateway in sandboxes:** VPCs, subnets, route tables, and security groups are free on AWS, whereas a single NAT Gateway costs ~$32/month idle. Private subnets intentionally omit NAT Gateways in this lab.
- **IAM-first real AWS sandbox:** `envs/aws-sandbox/` defaults `enable_network = false` so verifying OIDC providers, permission boundaries, and scoped roles against a real AWS account stays at $0.
