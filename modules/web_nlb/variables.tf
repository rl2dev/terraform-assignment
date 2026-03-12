variable "vpc_id" {
  description = "VPC ID for the workload NLB"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the NLB (first two used)"
  type        = list(string)
}

variable "nlb_name" {
  description = "Name of the Network Load Balancer"
  type        = string
  default     = "workload-vpc-nlb"
}
