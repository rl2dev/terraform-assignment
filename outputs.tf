output "internet_alb_dns" {
  description = "DNS name of the internet-facing ALB"
  value       = module.gateway_alb.alb_dns_name
}

output "workload_alb_dns" {
  description = "DNS name of the internal workload ALB"
  value       = module.web_alb.alb_dns_name
}

output "workload_nlb_dns" {
  description = "DNS name of the workload NLB"
  value       = module.web_nlb.nlb_dns_name
}
