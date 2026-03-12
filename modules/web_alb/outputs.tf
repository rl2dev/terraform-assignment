output "alb_id" {
  description = "ID of the workload ALB"
  value       = aws_lb.workload_alb.id
}

output "alb_arn" {
  description = "ARN of the workload ALB"
  value       = aws_lb.workload_alb.arn
}

output "alb_target_group_arn" {
  description = "ARN of the ALB target group (for ECS service)"
  value       = aws_lb_target_group.workload_alb_tg.arn
}

output "alb_security_group_id" {
  description = "Security group ID of the workload ALB"
  value       = aws_security_group.workload_alb_sg.id
}

output "alb_dns_name" {
  description = "DNS name of the workload ALB"
  value       = aws_lb.workload_alb.dns_name
}
