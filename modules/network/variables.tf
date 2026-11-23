variable "name_prefix" {
  description = "Prefix applied to network resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnets" {
  description = "Map of public subnets keyed by logical name (using maps with for_each avoids index-shift recreations)."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.public_subnets) > 0 && alltrue([for s in values(var.public_subnets) : can(cidrnetmask(s.cidr_block))])
    error_message = "public_subnets must contain at least one subnet with a valid IPv4 CIDR block."
  }
}

variable "private_subnets" {
  description = "Map of private subnets keyed by logical name."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.private_subnets) > 0 && alltrue([for s in values(var.private_subnets) : can(cidrnetmask(s.cidr_block))])
    error_message = "private_subnets must contain at least one subnet with a valid IPv4 CIDR block."
  }
}

variable "allowed_https_cidrs" {
  description = "CIDR blocks permitted to reach the identity proxy security group on TCP 443."
  type        = list(string)
  default     = ["10.0.0.0/8"]

  validation {
    condition     = length(var.allowed_https_cidrs) > 0 && alltrue([for c in var.allowed_https_cidrs : can(cidrnetmask(c))])
    error_message = "allowed_https_cidrs must contain at least one valid IPv4 CIDR block."
  }
}

variable "tags" {
  description = "Additional tags applied to network resources."
  type        = map(string)
  default     = {}
}
