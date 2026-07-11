# modules/security/variables.tf
variable "name" {
  type        = string
  description = "Name prefix."
}
variable "vpc_id" {
  type        = string
  description = "VPC ID (from the vpc module output)."
}
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR (for intra-VPC egress rules)."
}
variable "app_port" {
  type        = number
  default     = 8080
  description = "Port the app listens on (ALB -> app)."
}
variable "db_port" {
  type        = number
  default     = 5432
  description = "Database port (app -> db). 5432 Postgres, 3306 MySQL."
}
variable "tags" {
  type    = map(string)
  default = {}
}
