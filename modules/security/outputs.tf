# modules/security/outputs.tf
output "alb_sg_id" {
  value       = aws_security_group.alb.id
  description = "ALB security group ID."
}
output "app_sg_id" {
  value       = aws_security_group.app.id
  description = "App tier security group ID."
}
output "db_sg_id" {
  value       = aws_security_group.db.id
  description = "DB tier security group ID."
}
