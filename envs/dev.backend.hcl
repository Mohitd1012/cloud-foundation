# envs/dev.backend.hcl — backend config for DEV state.
# Use with: terraform init -backend-config=envs/dev.backend.hcl
bucket         = "tf-state-570461445597"   # <-- your unique bucket
key            = "cloud-foundation/dev/terraform.tfstate"
region         = "us-east-1"
use_lockfile   = true
