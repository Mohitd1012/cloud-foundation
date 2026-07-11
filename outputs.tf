# outputs.tf — what you get after `terraform apply`.

output "alb_dns_name" {
  value       = module.compute.alb_dns_name
  description = "Hit this URL to reach the app: http://<alb_dns_name>/healthz"
}
output "vpc_id" {
  value = module.vpc.vpc_id
}
output "db_endpoint" {
  value       = module.data.db_endpoint
  description = "RDS endpoint (resolves only inside the VPC)."
}
output "db_secret_arn" {
  value       = module.data.db_secret_arn
  description = "Read the live DB creds with: aws secretsmanager get-secret-value --secret-id <arn>"
}
