resource "aws_security_group" "aurora_sg" {
  name        = "aurora-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "aurora-subnet-group"
  subnet_ids = var.database_subnet_ids
}

resource "aws_rds_cluster" "aurora_postgres" {
  cluster_identifier = var.cluster_identifier
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.master_username
  master_password    = var.master_password
  storage_encrypted  = true

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  availability_zones     = var.availability_zones
  vpc_security_group_ids = [aws_security_group.aurora_sg.id]

  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }
}

resource "aws_rds_cluster_instance" "aurora_postgres_instance" {
  cluster_identifier = aws_rds_cluster.aurora_postgres.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora_postgres.engine
  engine_version     = aws_rds_cluster.aurora_postgres.engine_version
}
