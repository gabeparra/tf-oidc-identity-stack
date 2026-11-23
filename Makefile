COMPOSE ?= podman compose
TF_DIR  ?= envs/local
AWS_LOCAL := AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 aws --endpoint-url=http://localhost:4566

.PHONY: up down logs init fmt validate plan apply destroy state lint scan check aws-ls

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

init:
	terraform -chdir=$(TF_DIR) init

fmt:
	terraform fmt -recursive

fmt-check:
	terraform fmt -check -recursive -diff

validate:
	terraform -chdir=$(TF_DIR) validate

plan:
	terraform -chdir=$(TF_DIR) plan -out=tfplan

apply:
	terraform -chdir=$(TF_DIR) apply tfplan

destroy:
	terraform -chdir=$(TF_DIR) destroy

state:
	terraform -chdir=$(TF_DIR) state list

lint:
	tflint --recursive

scan:
	trivy config --severity HIGH,CRITICAL .

check: fmt-check validate lint scan

aws-ls:
	$(AWS_LOCAL) s3 ls
	$(AWS_LOCAL) iam list-roles --query 'Roles[].RoleName'
