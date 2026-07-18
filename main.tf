# main.tf — ROOT MODULE: composes the four modules into a working 3-tier stack.
#
# This is the "wiring diagram". Notice how outputs of one module become inputs of the next —
# that composition (not hardcoded IDs) is what makes the design reusable and is exactly what
# interviewers want to hear when they ask "how do you structure Terraform".
#
# Dependency order (Terraform figures it out from references, but conceptually):
#   vpc -> security -> data -> compute

locals {
  name = "${var.project}-${var.environment}" # e.g. cloudfound-dev
  tags = { Stack = local.name }
}

module "vpc" {
  source             = "./modules/vpc"
  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway # dev=true(cheap), prod=false(HA)
  tags               = local.tags
}

module "security" {
  source            = "./modules/security"
  name              = local.name
  vpc_id            = module.vpc.vpc_id # <- consumes vpc output
  vpc_cidr          = module.vpc.vpc_cidr
  app_port          = var.app_port
  db_port           = var.db_port
  public_subnet_ids = module.vpc.public_subnet_ids # NACLs attach per tier (stateless layer)
  app_subnet_ids    = module.vpc.app_subnet_ids
  data_subnet_ids   = module.vpc.data_subnet_ids
  tags              = local.tags
}

module "data" {
  source                = "./modules/data"
  name                  = local.name
  data_subnet_ids       = module.vpc.data_subnet_ids
  db_sg_id              = module.security.db_sg_id # <- only the app SG can reach the DB
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  tags                  = local.tags
}

module "compute" {
  source            = "./modules/compute"
  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  app_subnet_ids    = module.vpc.app_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  app_sg_id         = module.security.app_sg_id
  db_secret_arn     = module.data.db_secret_arn # <- app role gets read on ONLY this secret
  app_port          = var.app_port
  instance_type     = var.instance_type
  desired_capacity  = var.desired_capacity
  min_size          = var.min_size
  max_size          = var.max_size
  tags              = local.tags
}
