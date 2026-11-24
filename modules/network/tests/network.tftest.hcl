mock_provider "aws" {}

run "valid_vpc_and_for_each_subnets" {
  command = plan

  variables {
    name_prefix = "tf-oidc-test"
    vpc_cidr    = "10.40.0.0/16"
    public_subnets = {
      az_a = { cidr_block = "10.40.1.0/24", availability_zone = "us-east-1a" }
      az_b = { cidr_block = "10.40.2.0/24", availability_zone = "us-east-1b" }
    }
    private_subnets = {
      az_a = { cidr_block = "10.40.11.0/24", availability_zone = "us-east-1a" }
      az_b = { cidr_block = "10.40.12.0/24", availability_zone = "us-east-1b" }
    }
    allowed_https_cidrs = ["10.40.0.0/16"]
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support && aws_vpc.this.enable_dns_hostnames
    error_message = "VPC must enable DNS support and hostnames."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expected two public and two private subnets keyed by map name."
  }

  assert {
    condition     = alltrue([for s in values(aws_subnet.public) : s.map_public_ip_on_launch == false])
    error_message = "Public subnets must not auto-assign public IPs by default."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.https_in["10.40.0.0/16"].from_port == 443 && aws_vpc_security_group_ingress_rule.https_in["10.40.0.0/16"].to_port == 443
    error_message = "Identity proxy ingress must be restricted to TCP 443."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.internal_https_out.cidr_ipv4 == "10.40.0.0/16"
    error_message = "Identity proxy egress must stay scoped to the VPC CIDR."
  }
}

run "rejects_invalid_vpc_cidr" {
  command = plan

  variables {
    name_prefix = "tf-oidc-test"
    vpc_cidr    = "not-a-cidr"
    public_subnets = {
      az_a = { cidr_block = "10.40.1.0/24", availability_zone = "us-east-1a" }
    }
    private_subnets = {
      az_a = { cidr_block = "10.40.11.0/24", availability_zone = "us-east-1a" }
    }
  }

  expect_failures = [
    var.vpc_cidr,
  ]
}

run "rejects_empty_https_cidrs" {
  command = plan

  variables {
    name_prefix = "tf-oidc-test"
    vpc_cidr    = "10.40.0.0/16"
    public_subnets = {
      az_a = { cidr_block = "10.40.1.0/24", availability_zone = "us-east-1a" }
    }
    private_subnets = {
      az_a = { cidr_block = "10.40.11.0/24", availability_zone = "us-east-1a" }
    }
    allowed_https_cidrs = []
  }

  expect_failures = [
    var.allowed_https_cidrs,
  ]
}
