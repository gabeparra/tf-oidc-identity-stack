terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.11"
    }
  }
}
