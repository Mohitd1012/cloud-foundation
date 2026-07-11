# envs/prod.backend.hcl — backend config for PROD state (separate key = separate state file).
# Use with: terraform init -reconfigure -backend-config=envs/prod.backend.hcl
bucket         = "my-tf-state-bucket"
key            = "cloud-foundation/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "tf-state-lock"
