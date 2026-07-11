# modules/data/variables.tf
variable "name" { type = string }
variable "data_subnet_ids" {
  type        = list(string)
  description = "Private data subnets for the DB subnet group."
}
variable "db_sg_id" {
  type        = string
  description = "DB security group (allows app tier only)."
}
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "db_username" {
  type    = string
  default = "appadmin"
}
variable "engine_version" {
  type    = string
  default = "16.3"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "multi_az" {
  type        = bool
  default     = false # dev: false (cheaper). prod: true (HA standby + auto-failover).
  description = "Synchronous standby in a second AZ for automatic failover."
}
variable "skip_final_snapshot" {
  type    = bool
  default = true # dev: true. prod: false (keep a snapshot on delete).
}
variable "deletion_protection" {
  type    = bool
  default = false # prod: true.
}
variable "tags" {
  type    = map(string)
  default = {}
}
