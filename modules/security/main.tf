# modules/security/main.tf — SECURITY GROUPS (Troubleshooting Q12 & Q13).
#
# The golden rule demonstrated here: TIER-TO-TIER least privilege.
#   internet --(443/80)--> ALB --(8080)--> app --(5432)--> db
# Each tier's SG only accepts traffic FROM the SG of the tier directly in front of it
# (referencing security_groups, NOT cidr 0.0.0.0/0). This is the answer to "how do you
# implement least privilege at the network layer".
#
# SG vs NACL (the classic gotcha, Q13):
#   - Security Group = STATEFUL. Return traffic is auto-allowed. Attached to ENIs.
#   - NACL          = STATELESS. You must allow BOTH directions + ephemeral ports 1024-65535.
#   We rely on SGs here (the modern best practice); NACLs are a coarse second layer.
#
# AZURE: Security Group -> Network Security Group (NSG), also stateful.
# GCP:   Security Group -> VPC Firewall Rules (stateful), applied by network tags/service accounts.

# ---------------- ALB SG: open to the internet on 80/443 only ----------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB: allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

# ---------------- APP SG: ONLY accepts traffic from the ALB SG ----------------
# Troubleshooting Q12: if this ingress is missing/wrong, the ALB gets 502 (can't reach targets).
resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "App tier: allow app port from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from ALB SG only"
    from_port       = var.app_port           # e.g. 8080
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # ✅ reference the SG, not a CIDR → least privilege
  }
  # NOTE: deliberately NO SSH (22) from the internet. Use SSM Session Manager for shell access
  #       (no bastion, no open port 22, fully audited). This is the senior-grade answer.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # app needs egress (NAT) to pull packages / call the DB
  }
  tags = merge(var.tags, { Name = "${var.name}-app-sg" })
}

# ---------------- DB SG: ONLY accepts the DB port from the app SG ----------------
resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "DB tier: allow DB port from app SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB port from app SG only"
    from_port       = var.db_port            # 5432 (Postgres) / 3306 (MySQL)
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]   # ✅ DB is unreachable except from the app tier
  }
  # No egress to the internet needed for a managed DB; keep it locked down.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]   # only intra-VPC egress
  }
  tags = merge(var.tags, { Name = "${var.name}-db-sg" })
}
