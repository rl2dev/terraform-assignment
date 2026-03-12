output "alb_id" {
  description = "ID of the internet ALB"
  value       = aws_lb.internet_alb.id
}

output "alb_arn" {
  description = "ARN of the internet ALB"
  value       = aws_lb.internet_alb.arn
}

output "alb_dns_name" {
  description = "DNS name of the internet ALB"
  value       = aws_lb.internet_alb.dns_name
}

output "target_group_arn" {
  description = "ARN of the internet ALB target group"
  value       = aws_lb_target_group.internet_alb_tg.arn
}
