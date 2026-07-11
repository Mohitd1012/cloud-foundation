# providers.tf — AWS provider config.
# default_tags applies these to EVERY resource automatically (cost allocation / ownership /
# the "tagging strategy" interview answer). No need to repeat them in each module.

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "cloud-foundation"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}

# ----------------------------------------------------------------------------
# AZURE equivalent:
#   provider "azurerm" { features {} subscription_id = var.subscription_id }
# GCP equivalent:
#   provider "google"  { project = var.project_id  region = var.region }
# ----------------------------------------------------------------------------
