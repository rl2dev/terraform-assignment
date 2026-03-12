resource "aws_ec2_transit_gateway" "transit_gateway" {
  description = var.tgw_description
}

## Internet VPC Attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "internet_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = var.internet_vpc_id
  subnet_ids         = [var.internet_vpc_private_subnet_ids[0]]
}

## Workload VPC Attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "workload_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = var.workload_vpc_id
  subnet_ids         = [var.workload_vpc_private_subnet_ids[0]]
}

### ROUTE TABLES ###

# TGW Route Table
resource "aws_ec2_transit_gateway_route_table" "tgw_route_table" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
}

# Associate VPC attachments with our TGW route table (replace default association)
resource "aws_ec2_transit_gateway_route_table_association" "internet_vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  replace_existing_association   = true
}

resource "aws_ec2_transit_gateway_route_table_association" "workload_vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  replace_existing_association   = true
}

### ROUTES ###

# TGW Route to Internet VPC
resource "aws_ec2_transit_gateway_route" "tgw_to_internet" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment.id
}

# TGW Route to Workload VPC
resource "aws_ec2_transit_gateway_route" "tgw_to_workload" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  destination_cidr_block         = var.workload_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment.id
}

# Internet VPC: Route to Workload VPC via TGW
resource "aws_route" "internet_to_workload" {
  for_each               = { for i, rt_id in var.internet_vpc_public_route_table_ids : tostring(i) => rt_id }
  route_table_id         = each.value
  destination_cidr_block = var.workload_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment]
}

# Workload VPC: Route to Internet VPC via TGW
resource "aws_route" "workload_to_internet" {
  for_each               = { for i, rt_id in var.workload_vpc_private_route_table_ids : tostring(i) => rt_id }
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment]
}
