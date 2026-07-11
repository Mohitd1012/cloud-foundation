# modules/security/nacls.tf — NETWORK ACLs: the STATELESS second layer (Troubleshooting Q13).
#
# THE INTERVIEW POINT: SGs are stateful (return traffic auto-allowed); NACLs are STATELESS —
# you must explicitly allow BOTH directions, including the EPHEMERAL PORT RANGE (1024-65535)
# for return traffic. The classic outage: someone adds an inbound NACL rule but forgets the
# ephemeral return range → connections open, responses die. Every "return traffic" rule below
# is the fix for that bug.
#
# Defense in depth: SGs do the fine-grained tier-to-tier work; NACLs are the coarse subnet-level
# backstop (e.g. data subnets can NEVER talk to the internet, even if someone fat-fingers a SG).

# ---------------- PUBLIC tier NACL (ALB + NAT gateway live here) ----------------
resource "aws_network_acl" "public" {
  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-public-nacl" })
}

resource "aws_network_acl_rule" "public_in_http" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_in_https" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ❗ Return traffic TO the NAT gateway (responses from the internet) and app→ALB replies.
# Delete this rule and every `yum install` in the private subnets hangs — that's Q13 live.
resource "aws_network_acl_rule" "public_in_ephemeral" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 120
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# App-tier traffic entering the public subnets on its way OUT through the NAT gateway
# (any destination port — NAT forwards whatever the app sends).
resource "aws_network_acl_rule" "public_in_from_vpc" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 130
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
}

resource "aws_network_acl_rule" "public_out_all" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0" # NAT forwards to any port; ALB replies to client ephemeral ports
}

# ---------------- APP tier NACL (private: ASG instances) ----------------
resource "aws_network_acl" "app" {
  vpc_id     = var.vpc_id
  subnet_ids = var.app_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-app-nacl" })
}

# ALB (and anything intra-VPC) → app port. Coarser than the SG on purpose: the SG
# narrows this to "from the ALB's SG only".
resource "aws_network_acl_rule" "app_in_app_port" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = var.app_port
  to_port        = var.app_port
}

# ❗ Return traffic: responses from the internet (via NAT) and from the DB land on
# the app's ephemeral source ports. Stateless = must be explicit.
resource "aws_network_acl_rule" "app_in_ephemeral" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "app_out_https" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "app_out_http" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "app_out_db" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = var.db_port
  to_port        = var.db_port
}

# ❗ Replies back to the ALB, which initiated from ITS ephemeral ports.
resource "aws_network_acl_rule" "app_out_ephemeral" {
  network_acl_id = aws_network_acl.app.id
  rule_number    = 130
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# ---------------- DATA tier NACL (private: RDS) — internet-dark by construction ----------------
# No 0.0.0.0/0 rule in either direction: even a misconfigured SG cannot expose the DB.
resource "aws_network_acl" "data" {
  vpc_id     = var.vpc_id
  subnet_ids = var.data_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-data-nacl" })
}

resource "aws_network_acl_rule" "data_in_db_port" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = var.db_port
  to_port        = var.db_port
}

# ❗ Replies to the app tier's ephemeral ports — intra-VPC only.
resource "aws_network_acl_rule" "data_out_ephemeral" {
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 1024
  to_port        = 65535
}
