# envs/prod.backend.hcl — backend config for PROD state (separate key = separate state file).
# Use with: terraform init -reconfigure -backend-config=envs/prod.backend.hcl
bucket         = "tf-state-570461445597"
key            = "cloud-foundation/prod/terraform.tfstate"
region         = "us-east-1"
use_lockfile   = true
