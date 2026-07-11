# backend.tf — REMOTE STATE + LOCKING (Troubleshooting Q7).
#
# WHY (interview gold): local state on a laptop = no collaboration, no locking, easy to lose.
# Remote state in S3 gives a shared source of truth; the DynamoDB table provides a LOCK so two
# engineers running `terraform apply` at once can't corrupt state — the 2nd apply blocks.
#
# Bootstrap chicken-and-egg: the S3 bucket + DynamoDB table must exist BEFORE this backend works.
# Create them once (manually, or with a tiny separate "bootstrap" stack), then init.
#
#   aws s3api create-bucket --bucket my-tf-state-bucket --region us-east-1
#   aws s3api put-bucket-versioning --bucket my-tf-state-bucket \
#       --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name tf-state-lock \
#       --attribute-definitions AttributeName=LockID,AttributeType=S \
#       --key-schema AttributeName=LockID,KeyType=HASH \
#       --billing-mode PAY_PER_REQUEST
#
# NOTE: backend blocks can't use variables — values must be literals or passed via
# `terraform init -backend-config=...`. Per-env keys keep dev/prod state separate.

# PARTIAL CONFIG: the per-env values (especially `key`) are supplied at init time via
#   terraform init -backend-config=envs/dev.backend.hcl
# so dev and prod keep SEPARATE state files from one root module. This is why the block
# below is mostly empty — only the truly static `encrypt` lives here.
terraform {
  backend "s3" {
    encrypt = true # ✅ encrypt state at rest (it can contain secrets like the DB password)
    # bucket, key, region, dynamodb_table come from envs/<env>.backend.hcl
  }

  # --------------------------------------------------------------------------
  # AZURE remote state equivalent (azurerm backend — locking is automatic via
  # blob leases, no separate lock table needed):
  #   backend "azurerm" {
  #     resource_group_name  = "tfstate-rg"
  #     storage_account_name = "tfstatestorage"
  #     container_name       = "tfstate"
  #     key                  = "cloud-foundation/dev.terraform.tfstate"
  #   }
  #
  # GCP remote state equivalent (gcs backend — locking automatic via object generations):
  #   backend "gcs" {
  #     bucket = "my-tf-state-bucket"
  #     prefix = "cloud-foundation/dev"
  #   }
  # --------------------------------------------------------------------------
}
