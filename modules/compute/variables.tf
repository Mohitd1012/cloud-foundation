# modules/compute/variables.tf
variable "name" { type = string }
variable "vpc_id" { type = string }

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets for the ALB."
}
variable "app_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the ASG."
}
variable "alb_sg_id" { type = string }
variable "app_sg_id" { type = string }

variable "db_secret_arn" {
  type        = string
  description = "ARN of the DB secret the app role may read (least privilege)."
}

variable "app_port" {
  type    = number
  default = 8080
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "min_size" {
  type    = number
  default = 2 # 2 = survives one AZ/instance loss (HA)
}
variable "max_size" {
  type    = number
  default = 4
}
variable "desired_capacity" {
  type    = number
  default = 2
}
variable "tags" {
  type    = map(string)
  default = {}
}
