# envs/dev.backend.hcl — backend config for DEV state.
# Use with: terraform init -backend-config=envs/dev.backend.hcl
bucket         = "my-tf-state-bucket"   # <-- your unique bucket
key            = "cloud-foundation/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "tf-state-lock"
