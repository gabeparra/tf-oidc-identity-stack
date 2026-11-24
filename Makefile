COMPOSE ?= podman compose
TF_DIR  ?= envs/local
KC_PASS ?= localdevadmin
AWS_LOCAL := AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566

.PHONY: up down logs bootstrap init fmt fmt-check validate plan apply destroy state lint-init lint scan test test-e2e check aws-ls

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

bootstrap:
	terraform -chdir=bootstrap/local init
	terraform -chdir=bootstrap/local apply -auto-approve

init:
	terraform -chdir=$(TF_DIR) init

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive -diff

validate:
	terraform -chdir=bootstrap/local validate
	terraform -chdir=envs/local validate
	terraform -chdir=envs/aws-sandbox init -backend=false -input=false >/dev/null
	terraform -chdir=envs/aws-sandbox validate

plan:
	TF_VAR_keycloak_admin_password=$(KC_PASS) terraform -chdir=$(TF_DIR) plan -out=tfplan

apply:
	TF_VAR_keycloak_admin_password=$(KC_PASS) terraform -chdir=$(TF_DIR) apply tfplan

destroy:
	TF_VAR_keycloak_admin_password=$(KC_PASS) terraform -chdir=$(TF_DIR) destroy

state:
	terraform -chdir=$(TF_DIR) state list

lint-init:
	tflint --init

lint:
	tflint --recursive

scan:
	trivy config --severity HIGH,CRITICAL --exit-code 1 .

test:
	@set -e; for mod in modules/s3-secure-bucket modules/network modules/iam-oidc modules/keycloak-oidc; do \
		echo "==> terraform test $$mod"; \
		terraform -chdir=$$mod init -backend=false -input=false >/dev/null; \
		terraform -chdir=$$mod test; \
	done

test-e2e:
	./scripts/verify-local-e2e.sh

check: fmt-check validate test lint scan

aws-ls:
	$(AWS_LOCAL) s3 ls
	$(AWS_LOCAL) ec2 describe-vpcs --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock}'
	$(AWS_LOCAL) iam list-open-id-connect-providers
	$(AWS_LOCAL) iam list-roles --query 'Roles[].RoleName'
