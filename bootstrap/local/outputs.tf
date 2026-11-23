output "tfstate_bucket_name" {
  description = "Name of the S3 remote state bucket."
  value       = module.tfstate_bucket.bucket_id
}

output "tfstate_bucket_arn" {
  description = "ARN of the S3 remote state bucket."
  value       = module.tfstate_bucket.bucket_arn
}
