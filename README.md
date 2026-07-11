# Project 1 — Cloud Foundation (AWS, Terraform)

A production-shaped, multi-AZ **3-tier AWS environment** built entirely in Terraform with remote
state + locking. This is the "infrastructure" layer of the interview-prep platform
(see `../02_project_plan.md`). AWS-specific, with Azure/GCP equivalents noted in code comments.

## What it builds
```
                 Internet
                    │
            ┌───────▼────────┐   public subnets (2-3 AZs)
            │      ALB        │   + NAT gateways
            └───────┬────────┘
                    │ :8080 (ALB SG only)
            ┌───────▼────────┐   private APP subnets
            │  ASG of EC2    │   (egress via NAT, SSM for shell)
            └───────┬────────┘
                    │ :5432 (app SG only)
            ┌───────▼────────┐   private DATA subnets
            │  RDS Multi-AZ  │   (no internet; creds in Secrets Manager)
            └────────────────┘
```

## Interview topics this proves you can do
- **VPC design** (the #1 AWS question): public/app/data subnets, IGW, NAT, route tables.
- **SG vs NACL**, least-privilege tier-to-tier security (`modules/security`).
- **Terraform**: remote state + DynamoDB locking, reusable modules, partial backend config, drift.
- **HA**: multi-AZ subnets, ASG, RDS Multi-AZ; **least-privilege IAM** (instance profile, scoped secret read).
- **Secrets**: random_password → Secrets Manager (no plaintext in code/state).
- **CI/DevSecOps**: fmt/validate/`tfsec`/plan-on-PR with OIDC (no static keys).

## Layout
```
.
├── versions.tf            # provider/core version pins
├── backend.tf             # S3 backend (partial config; key per env)
├── providers.tf           # aws provider + default_tags
├── main.tf                # composes the 4 modules
├── variables.tf / outputs.tf
├── modules/
│   ├── vpc/               # subnets, IGW, NAT, route tables
│   ├── security/          # ALB/app/db security groups
│   ├── compute/           # ALB, ASG, launch template, IAM instance profile
│   └── data/              # RDS Multi-AZ + Secrets Manager
├── envs/
│   ├── dev.tfvars  / dev.backend.hcl
│   └── prod.tfvars / prod.backend.hcl
└── .github/workflows/terraform.yml
```

## Prerequisites (one-time bootstrap)
The state bucket + lock table must exist before `init`. Create them once:
```bash
aws s3api create-bucket --bucket my-tf-state-bucket --region us-east-1
aws s3api put-bucket-versioning --bucket my-tf-state-bucket \
    --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name tf-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
```
Then edit the bucket name in `backend.tf` examples and `envs/*.backend.hcl`.

## Usage
```bash
# DEV
terraform init  -backend-config=envs/dev.backend.hcl
terraform plan  -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars

# reach the app
curl http://$(terraform output -raw alb_dns_name)/healthz   # -> ok

# PROD (separate state file)
terraform init -reconfigure -backend-config=envs/prod.backend.hcl
terraform apply -var-file=envs/prod.tfvars

# tear down (avoid charges)
terraform destroy -var-file=envs/dev.tfvars
```

## Deliberately break it (practice the troubleshooting playbook)
Work through `../03_troubleshooting_playbook.md`. High-value reps in THIS repo:
- **Q7 (state lock):** remove `dynamodb_table` from the backend, run two applies at once → corruption. Restore it.
- **Q9 (secret leak):** hardcode a `password = "..."` in `modules/data/main.tf`, `apply`, then grep the state file for it. Revert to `random_password`.
- **Q11 (no egress):** comment out the `nat_gateway_id` route in `modules/vpc/main.tf` → instances can't `yum update`. Restore.
- **Q12 (502):** change the target-group `health_check.path` to `/wrong` → targets go unhealthy → ALB 502. Fix the path.
- **Drift:** change a security group rule in the AWS console, run `terraform plan` → watch it detect drift → `apply` to reconcile.

## Cost note
NAT gateways + RDS + ALB cost money even when idle (~$1–3/day in dev). **`terraform destroy` when done.**

## Next
Project 2 (EKS + GitOps) reuses this `modules/vpc`. See `../02_project_plan.md`.
