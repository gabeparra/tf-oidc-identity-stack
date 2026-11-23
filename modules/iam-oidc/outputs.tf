output "oidc_provider_arn" {
  description = "ARN of the registered IAM OIDC provider."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "Issuer URL registered on the IAM OIDC provider."
  value       = aws_iam_openid_connect_provider.this.url
}

output "permission_boundary_arn" {
  description = "ARN of the IAM permission boundary policy."
  value       = aws_iam_policy.permission_boundary.arn
}

output "role_arns" {
  description = "Map of logical role keys to federated IAM role ARNs."
  value       = { for k, r in aws_iam_role.federated : k => r.arn }
}
