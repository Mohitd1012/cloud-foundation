# backend.tf — REMOTE STATE + LOCKING (Troubleshooting Q7).
#
# WHY (interview gold): local state on a laptop = no collaboration, no locking, easy to lose.
# Remote state in S3 gives a shared source of truth; `use_lockfile = true` (Terraform >= 1.10,
# GA in 1.11) makes S3 itself provide the LOCK — a `.tflock` object written with a conditional
# PUT — so two engineers running `terraform apply` at once can't corrupt state; the 2nd blocks.
#
# HISTORY NOTE (know both for interviews): before native S3 locking, the lock lived in a
# DynamoDB table (`dynamodb_table = "..."` + a LockID partition key). That argument is now
# DEPRECATED — no extra lock infrastructure is needed anymore, just the bucket.
#
# Bootstrap chicken-and-egg: the S3 bucket must exist BEFORE this backend works.
# Create it once (manually, or with a tiny separate "bootstrap" stack), then init.
#
#   aws s3api create-bucket --bucket my-tf-state-bucket --region us-east-1
#   aws s3api put-bucket-versioning --bucket my-tf-state-bucket \
#       --versioning-configuration Status=Enabled
#
# NOTE: backend blocks can't use variables — values must be literals or passed via
# `terraform init -backend-config=...`. Per-env keys keep dev/prod state separate.

# PARTIAL CONFIG: the per-env values (especially `key`) are supplied at init time via
#   terraform init -backend-config=envs/dev.backend.hcl
# so dev and prod keep SEPARATE state files from one root module. This is why the block
# below is mostly empty — only the truly static `encrypt` lives here.
terraform {
  backend "s3" {
    encrypt      = true # ✅ encrypt state at rest (it can contain secrets like the DB password)
    use_lockfile = true # ✅ native S3 locking (replaces the deprecated dynamodb_table argument)
    # bucket, key, region come from envs/<env>.backend.hcl
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
