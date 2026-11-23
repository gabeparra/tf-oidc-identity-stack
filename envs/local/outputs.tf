output "audit_logs_bucket_name" {
  description = "Name of the S3 bucket holding identity audit logs."
  value       = module.audit_logs_bucket.bucket_id
}

output "audit_logs_bucket_arn" {
  description = "ARN of the S3 bucket holding identity audit logs."
  value       = module.audit_logs_bucket.bucket_arn
}

output "vpc_id" {
  description = "ID of the local VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by logical AZ name."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs keyed by logical AZ name."
  value       = module.network.private_subnet_ids
}

output "keycloak_issuer_url" {
  description = "Local Keycloak realm OIDC issuer URL."
  value       = module.keycloak_oidc.issuer_url
}

output "keycloak_clients" {
  description = "Managed Keycloak OIDC client IDs."
  value = {
    confidential = module.keycloak_oidc.confidential_client_id
    public_spa   = module.keycloak_oidc.public_client_id
  }
}

output "keycloak_oidc_role_arns" {
  description = "Federated IAM role ARNs trusting Keycloak."
  value       = module.iam_oidc_keycloak.role_arns
}

output "github_oidc_role_arns" {
  description = "Federated IAM role ARNs trusting GitHub Actions."
  value       = module.iam_oidc_github.role_arns
}
