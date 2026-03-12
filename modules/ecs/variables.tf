variable "vpc_id" {
  description = "VPC ID for ECS tasks and security group"
  type        = string
}

variable "app_subnet_ids" {
  description = "Private subnet IDs for ECS service (app subnets)"
  type        = list(string)
}

variable "workload_alb_target_group_arn" {
  description = "ARN of the workload ALB target group to register ECS tasks"
  type        = string
}

variable "workload_alb_security_group_id" {
  description = "Security group ID of the workload ALB (for ECS SG ingress)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "workload-cluster"
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "echoserver-service"
}

variable "log_group_name" {
  description = "CloudWatch log group name for ECS"
  type        = string
  default     = "/ecs/echoserver"
}

variable "container_image" {
  description = "Container image for the echoserver"
  type        = string
  default     = "k8s.gcr.io/e2e-test-images/echoserver:2.5"
}

variable "container_port" {
  description = "Container port for the echoserver"
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "aws_region" {
  description = "AWS region for logs and resources"
  type        = string
  default     = "ap-southeast-1"
}
