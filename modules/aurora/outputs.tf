output "cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora_postgres.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint of the Aurora cluster"
  value       = aws_rds_cluster.aurora_postgres.reader_endpoint
}

output "cluster_id" {
  description = "ID of the Aurora cluster"
  value       = aws_rds_cluster.aurora_postgres.id
}

output "cluster_port" {
  description = "Port of the Aurora cluster"
  value       = aws_rds_cluster.aurora_postgres.port
}

output "security_group_id" {
  description = "ID of the Aurora security group"
  value       = aws_security_group.aurora_sg.id
}
