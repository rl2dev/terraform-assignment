###############################
########## GENERAL ############
###############################
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

###############################
######## INTERNET VPC #########
###############################
variable "internet_vpc_name" {
  description = "Name of the internet VPC"
  type        = string
  default     = "internet-vpc"
}

variable "internet_vpc_cidr" {
  description = "CIDR block for the internet VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "internet_vpc_azs" {
  description = "Availability zones for the internet VPC"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "internet_vpc_public_subnets" {
  description = "Public subnet CIDR blocks for the internet VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "internet_vpc_public_subnet_names" {
  description = "Names for the internet VPC public subnets"
  type        = list(string)
  default     = ["gateway-subnet-a", "gateway-subnet-b"]
}

variable "internet_vpc_private_subnets" {
  description = "Private subnet CIDR blocks for the internet VPC"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "internet_vpc_private_subnet_names" {
  description = "Names for the internet VPC private subnets"
  type        = list(string)
  default     = ["internet-tgw-subnet", "internet-firewall-subnet"]
}

variable "internet_vpc_enable_nat_gateway" {
  description = "Enable NAT gateway for the internet VPC"
  type        = bool
  default     = true
}

variable "internet_vpc_single_nat_gateway" {
  description = "Use a single NAT gateway for the internet VPC"
  type        = bool
  default     = true
}

###############################
######## WORKLOAD VPC #########
###############################
variable "workload_vpc_name" {
  description = "Name of the workload VPC"
  type        = string
  default     = "workload-vpc"
}

variable "workload_vpc_cidr" {
  description = "CIDR block for the workload VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "workload_vpc_azs" {
  description = "Availability zones for the workload VPC"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c", "ap-southeast-1a", "ap-southeast-1b"]
}

variable "workload_vpc_private_subnets" {
  description = "Private subnet CIDR blocks for the workload VPC"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24", "10.1.4.0/24", "10.1.5.0/24"]
}

variable "workload_vpc_private_subnet_names" {
  description = "Names for the workload VPC private subnets"
  type        = list(string)
  default     = ["workload-web-subnet-a", "workload-web-subnet-b", "workload-tgw-subnet", "workload-app-subnet-a", "workload-app-subnet-b"]
}

variable "workload_vpc_database_subnets" {
  description = "Database subnet CIDR blocks for the workload VPC"
  type        = list(string)
  default     = ["10.1.6.0/24", "10.1.7.0/24"]
}

variable "workload_vpc_database_subnet_names" {
  description = "Names for the workload VPC database subnets"
  type        = list(string)
  default     = ["workload-db-subnet-a", "workload-db-subnet-b"]
}

variable "workload_vpc_enable_nat_gateway" {
  description = "Enable NAT gateway for the workload VPC"
  type        = bool
  default     = false
}

variable "aurora_availability_zones" {
  description = "Availability zones for the Aurora cluster"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "aurora_master_password" {
  description = "Master password for the Aurora cluster"
  type        = string
  sensitive   = true
}

###############################
########## WEB NLB ############
###############################
variable "web_nlb_name" {
  description = "Name of the workload VPC network load balancer"
  type        = string
  default     = "workload-vpc-nlb"
}
