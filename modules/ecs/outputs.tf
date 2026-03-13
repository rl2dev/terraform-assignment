output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.cluster_id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_cluster.services["echoserver"].name
}

output "execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = aws_iam_role.ecs_exec.arn
}

output "ecs_security_group_id" {
  description = "ID of the ECS service security group"
  value       = aws_security_group.ecs_sg.id
}
