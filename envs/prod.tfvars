# envs/prod.tfvars — PROD values (high availability, no SPOFs).
# Apply with: terraform apply -var-file=envs/prod.tfvars

environment        = "prod"
region             = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]  # 3 AZs

single_nat_gateway = false  # one NAT PER AZ → no single point of failure
db_multi_az        = true   # synchronous standby + automatic failover

instance_type    = "t3.small"
desired_capacity = 3
min_size         = 3
max_size         = 9
