# versions.tf — pin Terraform core and provider versions.
# WHY (interview): unpinned providers cause "works on my machine" drift between engineers.
# The .terraform.lock.hcl file (commit it!) locks exact provider hashes for reproducible applies.

terraform {
  required_version = ">= 1.11.0" # native S3 state locking (use_lockfile) went GA in 1.11

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40" # ~> allows 5.x patch/minor, blocks 6.0 breaking changes
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # ----------------------------------------------------------------------------
  # AZURE equivalent provider block:
  #   azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  # GCP equivalent provider block:
  #   google  = { source = "hashicorp/google",  version = "~> 5.20" }
  # ----------------------------------------------------------------------------
}
