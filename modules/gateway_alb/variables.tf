variable "internet_vpc_id" {
  description = "VPC ID of the internet VPC"
  type        = string
}

variable "internet_public_subnet_ids" {
  description = "Public subnet IDs in internet VPC for the ALB"
  type        = list(string)
}

variable "workload_vpc_private_subnet_ids" {
  description = "Workload VPC private subnet IDs (first two) for NLB ENI lookup"
  type        = list(string)
}

variable "workload_nlb_name" {
  description = "Name of the workload NLB (for ENI data source filter)"
  type        = string
}

variable "alb_name" {
  description = "Name of the internet-facing ALB"
  type        = string
  default     = "internet-vpc-alb"
}

variable "target_group_name" {
  description = "Name of the internet ALB target group"
  type        = string
  default     = "internet-to-workload-tg"
}
