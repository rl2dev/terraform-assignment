variable "vpc_id" {
  description = "VPC ID for the workload ALB"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ALB (first two used)"
  type        = list(string)
}

variable "nlb_tg_arn" {
  description = "ARN of the NLB target group to attach this ALB to"
  type        = string
}

variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  default     = "workload-vpc-alb"
}

variable "target_group_name" {
  description = "Name of the ALB target group for ECS"
  type        = string
  default     = "ecs-task-tg"
}
