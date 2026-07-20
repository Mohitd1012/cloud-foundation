# modules/data/main.tf — RDS (Multi-AZ) + SECRETS MANAGER (Troubleshooting Q9).
#
# Demonstrates: managed DB, Multi-AZ HA (automatic failover to a standby in another AZ),
# encryption at rest, and the CORRECT secret-handling pattern (no plaintext passwords in code/state).
#
# AZURE: RDS -> Azure SQL / Flexible Server, Secrets Manager -> Key Vault.
# GCP:   RDS -> Cloud SQL, Secrets Manager -> Secret Manager.

# ---------------- Generate a strong random password ----------------
# WHY: never type a literal password into .tf (it lands in state in plaintext — the Q9 leak).
# random_password keeps the value out of your source; we hand it straight to Secrets Manager.
resource "random_password" "db" {
  length  = 24
  special = true
  # exclude chars RDS rejects in master passwords
  override_special = "!#$%^&*()-_=+[]{}"
}

# ---------------- Store the credential in Secrets Manager ----------------
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}/db/master"
  description = "Master credentials for ${var.name} RDS"
  tags        = var.tags
  # GOTCHA (learned the hard way): deleting a secret only SCHEDULES it (recovery window,
  # default 30 days) — recreating the same name then fails with "already scheduled for
  # deletion". Dev sets 0 = purge immediately on destroy; prod keeps the safety window.
  recovery_window_in_days = var.secret_recovery_window_days
  # PROD: attach a rotation Lambda for automatic credential rotation.
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result # the app reads THIS at runtime via its IAM role
  })
}

# ---------------- DB subnet group (private DATA subnets only) ----------------
resource "aws_db_subnet_group" "db" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.data_subnet_ids # ✅ RDS sits in the isolated data tier (no internet)
  tags       = var.tags
}

# ---------------- The RDS instance ----------------
resource "aws_db_instance" "main" {
  identifier     = "${var.name}-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = 20
  max_allocated_storage = 100  # storage autoscaling
  storage_encrypted     = true # ✅ encryption at rest (KMS). Interview: "encryption at rest vs in transit"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result # ✅ sourced from random_password, NOT a hardcoded literal

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [var.db_sg_id] # only the app SG can reach it (from security module)

  multi_az            = var.multi_az # ✅ HA: synchronous standby in a 2nd AZ, auto-failover
  publicly_accessible = false        # ✅ never expose a DB to the internet

  # Point-in-time recovery window (the RPO answer). Env-tunable: AWS free-plan
  # accounts cap this at 1 day (FreeTierRestrictionError if exceeded) — dev=1, prod=7.
  backup_retention_period = var.backup_retention_days
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  tags = merge(var.tags, { Name = "${var.name}-db" })
}
