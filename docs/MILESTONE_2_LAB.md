# Milestone 2 Lab: Remote State, VPC/IAM OIDC Federation, and Keycloak IaC

Milestone 2 moves the stack from single-bucket local state to a production-shaped multi-module layout running across LocalStack and a local Keycloak instance.

## Architecture Decisions to Know Cold

### 1. Why `bootstrap/local/` Exists Separately from `envs/local/`
The S3 bucket that stores Terraform state must not live inside the same state file it holds. Separating bootstrap from workloads prevents `terraform destroy` on an environment from attempting to delete its own remote state bucket.

### 2. Native S3 State Locking (`use_lockfile = true`) vs Legacy DynamoDB
- **Modern Terraform (1.10+):** `backend "s3"` supports `use_lockfile = true`. Terraform writes a `.tflock` object next to the state file using S3 conditional writes (`If-None-Match: *`). If another run holds the lock, S3 rejects the write with `412 PreconditionFailed`. No separate DynamoDB table is needed.
- **Legacy pattern (still common in existing codebases):** Older Terraform setups used `dynamodb_table = "terraform-locks"` with a `LockID` string partition key to coordinate locks. It is worth understanding both and knowing how to recover from a stuck lock (`terraform force-unlock <LOCK_ID>`, only after confirming no apply is running).

### 3. `for_each` Maps vs `count` Lists
Both `modules/network` (subnets) and `modules/iam-oidc` (federated roles) iterate over maps with `for_each`. With `count`, removing the first element of a list shifts every later index (`[1]` becomes `[0]`), forcing Terraform to destroy and recreate unaffected subnets or IAM roles. Map keys keep resource addresses stable (`aws_subnet.public["az_a"]`, `aws_iam_role.federated["audit-reader"]`).

### 4. OIDC Federation and Permission Boundaries (`modules/iam-oidc`)
- **Zero static keys:** Both Keycloak and GitHub Actions roles use `sts:AssumeRoleWithWebIdentity` instead of long-lived IAM user access keys.
- **Strict claim scoping:** Every trust policy enforces both `aud` (`StringEquals`) and `sub` (`StringLike`). Input validation rejects any bare `*` subject wildcard to block confused-deputy attacks.
- **Permission boundary:** Every federated role gets `permissions_boundary` attached. Effective permissions are the intersection of the role's identity policy and its boundary, with an explicit `Deny` on IAM privilege-escalation actions (`iam:CreateAccessKey`, `iam:PutRolePermissionsBoundary`, `iam:DeleteRolePermissionsBoundary`, `iam:AttachRolePolicy`).

### 5. Declarative Keycloak (`modules/keycloak-oidc`)
Instead of clicking through the Keycloak Admin Console, Terraform manages:
- Realm settings (short 15m access tokens, brute-force protection)
- Realm roles and group-to-role bindings
- Confidential API client and public PKCE (`S256`) SPA client with implicit and password grants disabled
- Custom `aws-federation` client scope injecting `sts.amazonaws.com` audience, `groups`, and `roles` claims
- A disabled placeholder upstream OIDC broker modeling enterprise federation (such as Microsoft Entra ID) without storing real tenant IDs or secrets

## Hands-On Checks

1. Start LocalStack + Keycloak:
   ```bash
   make up
   ```
2. Verify remote state exists in S3 (no `terraform.tfstate` file needed in `envs/local/`):
   ```bash
   AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
     aws --endpoint-url=http://localhost:4566 s3 ls s3://tf-oidc-identity-local-tfstate/local/
   ```
3. Inspect the Keycloak OIDC discovery endpoint that Terraform configured:
   ```bash
   curl -s http://localhost:8080/realms/identity-lab/.well-known/openid-configuration | jq '{issuer, token_endpoint, jwks_uri}'
   ```
4. Inspect the IAM OIDC trust policy and permission boundary in LocalStack:
   ```bash
   make aws-ls
   AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
     aws --endpoint-url=http://localhost:4566 iam get-role \
     --role-name tf-oidc-identity-local-gha-ci-plan
   ```
5. Check the real-AWS-ready sandbox environment validates offline without touching AWS:
   ```bash
   make validate
   ```
