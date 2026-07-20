# variables.tf — ROOT inputs. Values come from envs/<env>.tfvars.

variable "project" {
  type    = string
  default = "cloudfound"
}
variable "environment" {
  type        = string
  description = "dev | staging | prod"
}
variable "owner" {
  type    = string
  default = "platform-team"
}
variable "region" {
  type    = string
  default = "us-east-1"
}

# --- networking ---
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}

# --- app / ports ---
variable "app_port" {
  type    = number
  default = 8080
}
variable "db_port" {
  type    = number
  default = 5432
}

# --- compute sizing ---
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "desired_capacity" {
  type    = number
  default = 2
}
variable "min_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 4
}

# --- data ---
variable "db_multi_az" {
  type    = bool
  default = false
}
variable "db_backup_retention_days" {
  type    = number
  default = 1 # free-plan accounts cap RDS retention at 1 day; prod overrides to 7
}
variable "secret_recovery_window_days" {
  type    = number
  default = 0 # dev: purge on destroy (soft-delete blocks same-name recreate); prod: 30
}
