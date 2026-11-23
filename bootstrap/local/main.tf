# Bootstrap stack stays on local state so envs/local can safely store its remote
# state inside this bucket without a circular destroy dependency.
module "tfstate_bucket" {
  source = "../../modules/s3-secure-bucket"

  bucket_name                        = "${var.project_name}-${var.environment}-tfstate"
  versioning_enabled                 = true
  force_destroy                      = true
  noncurrent_version_expiration_days = 90

  tags = {
    Purpose = "terraform-state"
  }
}
