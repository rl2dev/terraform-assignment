variable "vpc_id" {
  description = "VPC ID for the Aurora security group"
  type        = string
}

variable "database_subnet_ids" {
  description = "Subnet IDs for the Aurora DB subnet group"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID of the ECS service (allowed to connect on port 5432)"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the Aurora cluster"
  type        = list(string)
}

variable "cluster_identifier" {
  description = "Identifier for the Aurora cluster"
  type        = string
  default     = "aurora-cluster"
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "13.9"
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "test"
}

variable "master_username" {
  description = "Master username for the Aurora cluster"
  type        = string
  default     = "root"
}

variable "master_password" {
  description = "Master password for the Aurora cluster"
  type        = string
  sensitive   = true
}

variable "min_capacity" {
  description = "Minimum ACU capacity for serverless v2 scaling"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum ACU capacity for serverless v2 scaling"
  type        = number
  default     = 1.0
}
