COMPOSE ?= podman compose
TF_DIR  ?= envs/local
KC_PASS ?= localdevadmin
AWS_LOCAL := AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566

.PHONY: up down logs bootstrap init fmt fmt-check validate plan apply destroy state lint scan check aws-ls

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

lint:
	tflint --recursive

scan:
	trivy config --severity HIGH,CRITICAL .

check: fmt-check validate lint scan

aws-ls:
	$(AWS_LOCAL) s3 ls
	$(AWS_LOCAL) ec2 describe-vpcs --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock}'
	$(AWS_LOCAL) iam list-open-id-connect-providers
	$(AWS_LOCAL) iam list-roles --query 'Roles[].RoleName'
