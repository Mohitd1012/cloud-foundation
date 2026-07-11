# modules/compute/outputs.tf
output "alb_dns_name" {
  value       = aws_lb.app.dns_name
  description = "Public DNS of the ALB — hit this to reach the app."
}
output "asg_name" {
  value       = aws_autoscaling_group.app.name
  description = "Auto Scaling Group name."
}
output "app_role_arn" {
  value       = aws_iam_role.app.arn
  description = "IAM role ARN attached to app instances."
}
