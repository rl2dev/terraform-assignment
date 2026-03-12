output "internet_alb_dns" {
  value = aws_lb.internet_alb.dns_name
}

output "workload_alb_dns" {
  value = aws_lb.workload_alb.dns_name
}

output "workload_nlb_dns" {
  value = aws_lb.workload_nlb.dns_name
}