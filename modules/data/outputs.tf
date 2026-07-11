# modules/data/outputs.tf
output "db_endpoint" {
  value       = aws_db_instance.main.address
  description = "RDS endpoint hostname (resolves only inside the VPC)."
}
output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db.arn
  description = "ARN of the DB secret — passed to compute so the app role can read ONLY this."
}
output "db_port" {
  value       = aws_db_instance.main.port
  description = "DB port."
}
