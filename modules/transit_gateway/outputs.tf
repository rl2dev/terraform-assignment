output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.transit_gateway.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.transit_gateway.arn
}

output "internet_vpc_attachment_id" {
  description = "ID of the internet VPC TGW attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment.id
}

output "workload_vpc_attachment_id" {
  description = "ID of the workload VPC TGW attachment"
  value       = aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment.id
}
