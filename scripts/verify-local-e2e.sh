#!/usr/bin/env bash
set -euo pipefail

LOCALSTACK_URL="${LOCALSTACK_URL:-http://localhost:4566}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"
KEYCLOAK_HEALTH_URL="${KEYCLOAK_HEALTH_URL:-http://localhost:9000/health/ready}"
KC_PASS="${TF_VAR_keycloak_admin_password:-localdevadmin}"

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export TF_VAR_keycloak_admin_password="${KC_PASS}"
export TF_IN_AUTOMATION="true"

aws_local() {
  aws --endpoint-url="${LOCALSTACK_URL}" "$@"
}

echo "==> Waiting for LocalStack (${LOCALSTACK_URL}) and Keycloak (${KEYCLOAK_HEALTH_URL})..."
for i in $(seq 1 60); do
  if curl -sf "${LOCALSTACK_URL}/_localstack/health" >/dev/null && curl -sf "${KEYCLOAK_HEALTH_URL}" >/dev/null; then
    echo "Services ready."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: Timed out waiting for LocalStack or Keycloak." >&2
    exit 1
  fi
  sleep 2
done

echo "==> Step 1: Bootstrap S3 remote state bucket (bootstrap/local)"
terraform -chdir=bootstrap/local init -input=false
terraform -chdir=bootstrap/local apply -auto-approve -input=false

echo "==> Step 2: Init, validate, plan, and apply envs/local (S3 backend + use_lockfile)"
terraform -chdir=envs/local init -reconfigure -input=false
terraform -chdir=envs/local validate
terraform -chdir=envs/local plan -input=false -out=tfplan
terraform -chdir=envs/local apply -input=false tfplan

echo "==> Step 3: Verify S3 remote state exists"
aws_local s3 ls s3://tf-oidc-identity-local-tfstate/local/terraform.tfstate

echo "==> Step 4: Verify clean idempotency (plan -detailed-exitcode must return 0)"
terraform -chdir=envs/local plan -input=false -detailed-exitcode

echo "==> Step 5: Out-of-band drift injection & detection (must return exit code 2)"
aws_local s3api put-public-access-block \
  --bucket tf-oidc-identity-local-audit-logs \
  --public-access-block-configuration \
  BlockPublicAcls=false,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

set +e
terraform -chdir=envs/local plan -input=false -detailed-exitcode
DRIFT_EXIT=$?
set -e

if [ "${DRIFT_EXIT}" -ne 2 ]; then
  echo "ERROR: Expected drift exit code 2, got ${DRIFT_EXIT}." >&2
  exit 1
fi
echo "Drift detected as expected (exit code 2). Reconciling..."

terraform -chdir=envs/local apply -auto-approve -input=false
terraform -chdir=envs/local plan -input=false -detailed-exitcode
echo "Drift reconciled cleanly (exit code 0)."

echo "==> Step 6: Verify live Keycloak OIDC discovery and IAM OIDC trust + permission boundary"
DISCOVERY_ISSUER=$(curl -sf "${KEYCLOAK_URL}/realms/identity-lab/.well-known/openid-configuration" | jq -r '.issuer')
if [ "${DISCOVERY_ISSUER}" != "${KEYCLOAK_URL}/realms/identity-lab" ]; then
  echo "ERROR: Unexpected Keycloak issuer: ${DISCOVERY_ISSUER}" >&2
  exit 1
fi
echo "Keycloak OIDC discovery issuer verified: ${DISCOVERY_ISSUER}"

OIDC_COUNT=$(aws_local iam list-open-id-connect-providers | jq '.OpenIDConnectProviderList | length')
if [ "${OIDC_COUNT}" -lt 2 ]; then
  echo "ERROR: Expected at least 2 IAM OIDC providers, found ${OIDC_COUNT}." >&2
  exit 1
fi

BOUNDARY_ARN=$(aws_local iam get-role --role-name tf-oidc-identity-local-gha-ci-plan | jq -r '.Role.PermissionsBoundary.PermissionsBoundaryArn')
if [[ "${BOUNDARY_ARN}" != *"tf-oidc-identity-local-gha-oidc-boundary" ]]; then
  echo "ERROR: Expected permission boundary on GitHub OIDC role, got: ${BOUNDARY_ARN}" >&2
  exit 1
fi
echo "IAM OIDC providers (${OIDC_COUNT}) and permission boundary (${BOUNDARY_ARN}) verified."

echo "==> All end-to-end local verification checks passed."
