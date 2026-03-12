
# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = var.log_group_name
  retention_in_days = 14
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_exec" {
  name = "ecs-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Create Policy Attachment to ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_exec" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = var.cluster_name

  # 1. Cluster Capacity Providers
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  #2. Services, Task Definitions, and Containers
  services = {
    echoserver = {
      name                     = var.service_name
      family                   = "echoserver-task"
      cpu                      = 256
      memory                   = 512
      desired_count            = var.desired_count
      network_mode             = "awsvpc"
      requires_compatibilities = ["FARGATE"]

      task_exec_iam_role_arn = aws_iam_role.ecs_exec.arn

      # Network configuration
      subnet_ids         = var.app_subnet_ids
      assign_public_ip   = false
      security_group_ids = [aws_security_group.ecs_sg.id]

      # Container definition
      container_definitions = {
        echoserver = {
          name      = "echoserver"
          image     = var.container_image
          essential = true

          readonly_root_filesystem = false

          port_mappings = [
            {
              containerPort = var.container_port
              protocol      = "tcp"
            }
          ]

          # Log Configuration
          log_configuration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = var.log_group_name
              "awslogs-region"        = var.aws_region
              "awslogs-stream-prefix" = "echoserver"
            }
          }
        }
      }

      # Load Balancer configuration
      load_balancer = {
        service = {
          target_group_arn = var.workload_alb_target_group_arn
          container_name   = "echoserver"
          container_port   = var.container_port
        }
      }
    }
  }
}

# 3. Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.container_port
    to_port         = var.container_port
    security_groups = [var.workload_alb_security_group_id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}