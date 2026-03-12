output "nlb_id" {
  description = "ID of the workload NLB"
  value       = aws_lb.workload_nlb.id
}

output "nlb_arn" {
  description = "ARN of the workload NLB"
  value       = aws_lb.workload_nlb.arn
}

output "nlb_name" {
  description = "Name of the workload NLB (for ENI lookups)"
  value       = aws_lb.workload_nlb.name
}

output "nlb_tg_arn" {
  description = "ARN of the NLB target group (targets ALB)"
  value       = aws_lb_target_group.nlb_tg.arn
}

output "nlb_dns_name" {
  description = "DNS name of the workload NLB"
  value       = aws_lb.workload_nlb.dns_name
}
