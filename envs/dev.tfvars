# envs/dev.tfvars — DEV values (cheap, single points of failure tolerated).
# Apply with: terraform apply -var-file=envs/dev.tfvars

environment        = "dev"
region             = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]

single_nat_gateway = true  # one NAT to save ~$32/mo (acceptable SPOF in dev)
db_multi_az        = false # no standby in dev

instance_type    = "t3.micro"
desired_capacity = 2
min_size         = 2
max_size         = 3

db_backup_retention_days    = 1 # free-plan cap
secret_recovery_window_days = 0 # dev: purge immediately so rebuilds work same-day
