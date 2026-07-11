# modules/vpc/variables.tf — module INPUTS.
# WHY (interview): typed variables with validation make a module reusable and self-documenting.

variable "name" {
  description = "Name prefix for all resources (e.g. 'cloudfound-dev')."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 gives room for many /24 subnets."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "availability_zones" {
  description = "AZs to span. 2+ for high availability (survives one AZ failure)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheap, dev). false = one NAT per AZ (HA, prod)."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to every resource (cost allocation, ownership)."
  type        = map(string)
  default     = {}
}
