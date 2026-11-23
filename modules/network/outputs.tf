output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of public subnet keys to subnet IDs."
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet keys to subnet IDs."
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "identity_proxy_sg_id" {
  description = "ID of the identity proxy security group."
  value       = aws_security_group.identity_proxy.id
}
