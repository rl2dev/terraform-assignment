variable "internet_vpc_id" {
  description = "VPC ID of the internet VPC"
  type        = string
}

variable "internet_vpc_private_subnet_ids" {
  description = "Private subnet IDs in internet VPC for TGW attachment"
  type        = list(string)
}

variable "internet_vpc_public_route_table_ids" {
  description = "Public route table IDs in internet VPC (for route to workload)"
  type        = list(string)
}

variable "workload_vpc_id" {
  description = "VPC ID of the workload VPC"
  type        = string
}

variable "workload_vpc_cidr" {
  description = "CIDR block of the workload VPC"
  type        = string
}

variable "workload_vpc_private_subnet_ids" {
  description = "Private subnet IDs in workload VPC for TGW attachment"
  type        = list(string)
}

variable "workload_vpc_private_route_table_ids" {
  description = "Private route table IDs in workload VPC (for default route via TGW)"
  type        = list(string)
}

variable "tgw_description" {
  description = "Description for the Transit Gateway"
  type        = string
  default     = "transit gateway for internet and workload VPCs"
}
