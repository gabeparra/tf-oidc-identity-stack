output "tfstate_bucket_name" {
  description = "Name of the S3 bucket reserved for Terraform remote state."
  value       = module.tfstate_bucket.bucket_id
}

output "tfstate_bucket_arn" {
  description = "ARN of the S3 bucket reserved for Terraform remote state."
  value       = module.tfstate_bucket.bucket_arn
}

output "audit_logs_bucket_name" {
  description = "Name of the S3 bucket holding identity audit logs."
  value       = module.audit_logs_bucket.bucket_id
}

output "audit_logs_bucket_arn" {
  description = "ARN of the S3 bucket holding identity audit logs."
  value       = module.audit_logs_bucket.bucket_arn
}

output "audit_reader_role_arn" {
  description = "ARN of the least-privilege audit reader IAM role."
  value       = aws_iam_role.audit_reader.arn
}
