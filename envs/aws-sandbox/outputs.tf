output "audit_logs_bucket_arn" {
  description = "ARN of the sandbox audit-logs bucket."
  value       = module.audit_logs_bucket.bucket_arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the registered GitHub Actions OIDC provider."
  value       = module.iam_oidc_github.oidc_provider_arn
}

output "github_oidc_role_arns" {
  description = "Federated IAM role ARNs trusting GitHub Actions."
  value       = module.iam_oidc_github.role_arns
}

output "vpc_id" {
  description = "VPC ID when enable_network is true, otherwise null."
  value       = try(module.network[0].vpc_id, null)
}
