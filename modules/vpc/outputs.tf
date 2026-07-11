# modules/vpc/outputs.tf — module OUTPUTS (how other modules consume this one).
# WHY (interview): outputs are the module's public API. The compute/data modules take
# these IDs as inputs — this is how you compose infrastructure without hardcoding.

output "vpc_id" {
  value       = aws_vpc.this.id
  description = "The VPC ID."
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets (for the ALB)."
}

output "app_subnet_ids" {
  value       = aws_subnet.app[*].id
  description = "IDs of the private app subnets (for the ASG)."
}

output "data_subnet_ids" {
  value       = aws_subnet.data[*].id
  description = "IDs of the private data subnets (for RDS)."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "The VPC CIDR (used for SG rules)."
}
