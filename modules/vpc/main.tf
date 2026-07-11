# modules/vpc/main.tf — the 3-tier NETWORK (the #1 most-asked AWS interview topic).
#
# Tiers, each in PRIVATE-vs-PUBLIC isolation across multiple AZs (high availability):
#   - public  subnets  -> ALB / NAT gateways         (route to Internet Gateway)
#   - app     subnets  -> EC2/ASG (private)          (egress via NAT only)
#   - data    subnets  -> RDS     (private, no NAT)  (no internet at all)
#
# AZURE mapping: VPC->VNet, Subnet->Subnet, IGW->(implicit) , NAT GW->NAT Gateway,
#               Route Table->Route Table/UDR.
# GCP mapping:  VPC->VPC (global), Subnet->Subnetwork (regional), IGW->(default internet
#               gateway route), NAT->Cloud NAT, Route Table->Routes.

locals {
  # Derive subnet CIDRs from the VPC CIDR, one per AZ per tier.
  # WHY cidrsubnet(): keeps math DRY and avoids hardcoding overlapping ranges (a classic bug).
  az_count = length(var.availability_zones)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr          # e.g. 10.0.0.0/16  → 65k addresses
  enable_dns_support   = true                  # ✅ needed for RDS endpoints / private DNS
  enable_dns_hostnames = true
  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

# ---------------- PUBLIC subnets (one per AZ) ----------------
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)       # 10.0.0.0/24, 10.0.1.0/24...
  map_public_ip_on_launch = true               # public subnet → instances get a public IP
  tags = merge(var.tags, {
    Name = "${var.name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
    # tag used by EKS/ALB auto-discovery later (Project 2):
    "kubernetes.io/role/elb" = "1"
  })
}

# ---------------- PRIVATE APP subnets ----------------
resource "aws_subnet" "app" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)         # 10.0.10.0/24...
  tags = merge(var.tags, {
    Name = "${var.name}-app-${var.availability_zones[count.index]}"
    Tier = "app"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ---------------- PRIVATE DATA subnets ----------------
resource "aws_subnet" "data" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 20)         # 10.0.20.0/24...
  tags = merge(var.tags, {
    Name = "${var.name}-data-${var.availability_zones[count.index]}"
    Tier = "data"
  })
}

# ---------------- NAT GATEWAY (egress for private subnets) ----------------
# COST/HA tradeoff (good interview answer): one NAT GW per AZ = HA but ~$32/mo each.
# var.single_nat_gateway=true uses ONE NAT to save money in dev (single point of failure).
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : local.az_count
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : local.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id   # ✅ NAT MUST live in a PUBLIC subnet
  tags          = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

# ---------------- ROUTE TABLES ----------------
# PUBLIC: default route -> Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(var.tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# PRIVATE APP: default route -> NAT Gateway (Troubleshooting Q11 — without this, no egress)
resource "aws_route_table" "app" {
  count  = local.az_count
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id # ✅ egress via NAT
  }
  tags = merge(var.tags, { Name = "${var.name}-rt-app-${count.index}" })
}

resource "aws_route_table_association" "app" {
  count          = local.az_count
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# PRIVATE DATA: NO default route to internet at all (most isolated tier).
# Only local VPC routing exists implicitly, so RDS can talk to the app tier but not the internet.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-rt-data" })
}

resource "aws_route_table_association" "data" {
  count          = local.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}
