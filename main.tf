provider "aws" {
  region = "ap-southeast-1"
}
###############################
######## INTERNET VPC #########
###############################
module "internet_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "internet-vpc"
  cidr = "10.0.0.0/16"

  azs                  = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_names  = ["gateway-subnet-a", "gateway-subnet-b"]
  private_subnets      = ["10.0.3.0/24", "10.0.4.0/24"]
  private_subnet_names = ["internet-tgw-subnet", "internet-firewall-subnet"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

## FIREWALL RESOURCES ##

# Already created by VPC module: aws_network_firewall.firewall

## GATEWAY RESOURCE ##

#Application Load Balancer
resource "aws_lb" "internet_alb" {
  name               = "internet-vpc-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internet_alb_sg.id]
  subnets            = module.internet_vpc.public_subnets
}

resource "aws_security_group" "internet_alb_sg" {
  name        = "internet-alb-sg"
  description = "public ALB security group"
  vpc_id      = module.internet_vpc.vpc_id

  # allow http traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # allow https traffic from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "internet-alb-sg"
  }
}


# Internet ALB Target Group - targets Workload NLB (cross-VPC via TGW)
resource "aws_lb_target_group" "internet_alb_tg" {
  name        = "internet-to-workload-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.internet_vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399" 
    interval            = 30
    timeout             = 10 
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# 1. Find the ENIs for the Workload NLB
data "aws_network_interfaces" "nlb_enis" {
  filter {
    name   = "description"
    values = ["ELB net/workload-vpc-nlb/*"]
  }
  filter {
    name   = "status"
    values = ["in-use"]
  }

  depends_on = [aws_lb.workload_nlb]
}

locals {
  # We define static keys ("az1", "az2") so Terraform knows 
  # how many resources to create before running.
  subnet_map = {
    "az1" = module.workload_vpc.private_subnets[0]
    "az2" = module.workload_vpc.private_subnets[1]
  }
}
# 2. Look up the ENI for each subnet
data "aws_network_interface" "nlb_eni_per_subnet" {
  for_each = local.subnet_map

  filter {
    name   = "description"
    # IMPORTANT: Ensure 'workload-vpc-nlb' matches your aws_lb.name exactly
    values = ["ELB net/workload-vpc-nlb/*"] 
  }

  filter {
    name   = "subnet-id"
    values = [each.value]
  }

  depends_on = [aws_lb.workload_nlb]
}

# 3. Attach using the same static keys
resource "aws_lb_target_group_attachment" "internet_alb_attachment" {
  for_each = data.aws_network_interface.nlb_eni_per_subnet

  target_group_arn  = aws_lb_target_group.internet_alb_tg.arn
  target_id         = each.value.private_ip
  port              = 80
  availability_zone = "all"
}

# Internet ALB Listener
resource "aws_lb_listener" "internet_alb_listener" {
  load_balancer_arn = aws_lb.internet_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.internet_alb_tg.arn
  }
}

###############################
######## WORKLOAD VPC #########
###############################
module "workload_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "workload-vpc"
  cidr = "10.1.0.0/16"

  azs                   = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c", "ap-southeast-1a", "ap-southeast-1b"]
  private_subnets       = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24", "10.1.4.0/24", "10.1.5.0/24"]
  private_subnet_names  = ["workload-web-subnet-a", "workload-web-subnet-b", "workload-tgw-subnet", "workload-app-subnet-a", "workload-app-subnet-b"]
  database_subnets      = ["10.1.6.0/24", "10.1.7.0/24"] # db (requires 2 AZs)
  database_subnet_names = ["workload-db-subnet-a", "workload-db-subnet-b"]

  enable_nat_gateway = false # Will use TGW to reach internet

  enable_dns_hostnames = true
  enable_dns_support   = true

}

## WEB RESOURCES ##

## NLB
resource "aws_lb" "workload_nlb" {
  name               = "workload-vpc-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [module.workload_vpc.private_subnets[0], module.workload_vpc.private_subnets[1]]

}

# NLB Target Group - targets Workload ALB
resource "aws_lb_target_group" "nlb_tg" {
  name        = "nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.workload_vpc.vpc_id
  target_type = "alb"

  health_check {
    enabled             = true
    protocol            = "HTTP" # NLB can "reach into" L7 for health checks
    path                = "/"    # echoserver responds here
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 3 # NLB defaults are slightly different
    unhealthy_threshold = 3
  }
}

# NLB Listener
resource "aws_lb_listener" "workload_nlb_listener" {
  load_balancer_arn = aws_lb.workload_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}

## ALB
resource "aws_lb" "workload_alb" {
  name               = "workload-vpc-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.workload_alb_sg.id]
  subnets            = [module.workload_vpc.private_subnets[0], module.workload_vpc.private_subnets[1]]
}

resource "aws_security_group" "workload_alb_sg" {
  name        = "workload-alb-sg"
  description = "Security group for workload ALB"
  vpc_id      = module.workload_vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # Allow from internal networks via TGW
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "workload-alb-sg"
  }
}

resource "aws_lb_target_group" "workload_alb_tg" {
  name        = "ecs-task-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.workload_vpc.vpc_id


  health_check {
    enabled             = true
    path                = "/"    # Echoserver returns 200 OK at root
    port                = "8080" # Explicitly check the app port
    protocol            = "HTTP"
    matcher             = "200" # Strict success code
    interval            = 15    # Faster checks for app-level health
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # This helps prevent connection drops during deployments
  deregistration_delay = 30
}

resource "aws_lb_listener" "workload_alb_listener" {
  load_balancer_arn = aws_lb.workload_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.workload_alb_tg.arn
  }
}


# Attach Workload ALB to NLB Target Group
resource "aws_lb_target_group_attachment" "nlb_to_alb" {
  target_group_arn = aws_lb_target_group.nlb_tg.arn
  target_id        = aws_lb.workload_alb.arn
  port             = 80

  depends_on = [aws_lb_listener.workload_alb_listener]
}


# Create CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/echoserver"
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


### APP RESOURCES ###

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0" 

  cluster_name = "workload-cluster"

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
      name                   = "echoserver-service"
      family                 = "echoserver-task"
      cpu                    = 256
      memory                 = 512
      desired_count          = 1
      network_mode           = "awsvpc"
      requires_compatibilities = ["FARGATE"]

      task_exec_iam_role_arn    = aws_iam_role.ecs_exec.arn

      # Network configuration
      subnet_ids         = [module.workload_vpc.private_subnets[3], module.workload_vpc.private_subnets[4]]
      assign_public_ip   = false
      security_group_ids = [aws_security_group.ecs_sg.id]

      # Container definition
      container_definitions = {
        echoserver = {
          name      = "echoserver"
          image     = "k8s.gcr.io/e2e-test-images/echoserver:2.5"
          essential = true

          readonly_root_filesystem = false

          port_mappings = [
            {
              containerPort = 8080
              protocol      = "tcp"
            }
          ]

          # Log Configuration
          log_configuration = {
            logDriver = "awslogs"
            options = {
              "awslogs-group"         = "/ecs/echoserver"
              "awslogs-region"        = "ap-southeast-1"
              "awslogs-stream-prefix" = "echoserver"
            }
          }
        }
      }

      # Load Balancer configuration
      load_balancer = {
        service = {
          target_group_arn = aws_lb_target_group.workload_alb_tg.arn
          container_name   = "echoserver"
          container_port   = 8080
        }
      }
    }
  }
}

# 3. Security Group 
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  vpc_id      = module.workload_vpc.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.workload_alb_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### TRANSIT GATEWAY ###
resource "aws_ec2_transit_gateway" "transit_gateway" {
  description = "transit gateway for internet and workload VPCs"
}

## Internet VPC Attachment to TGW 
resource "aws_ec2_transit_gateway_vpc_attachment" "internet_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = module.internet_vpc.vpc_id
  subnet_ids         = [module.internet_vpc.private_subnets[0]]
}

## Workload VPC Attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "workload_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = module.workload_vpc.vpc_id
  subnet_ids         = [module.workload_vpc.private_subnets[0]]
}

### ROUTE TABLES ###

# TGW Route Table
resource "aws_ec2_transit_gateway_route_table" "tgw_route_table" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
}

# Associate VPC attachments with our TGW route table (replace default association)
resource "aws_ec2_transit_gateway_route_table_association" "internet_vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  replace_existing_association   = true
}

resource "aws_ec2_transit_gateway_route_table_association" "workload_vpc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  replace_existing_association   = true
}

### ROUTES ###

# TGW Route to Internet VPC
resource "aws_ec2_transit_gateway_route" "tgw_to_internet" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment.id
}

# TGW Route to Workload VPC
resource "aws_ec2_transit_gateway_route" "tgw_to_workload" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table.id
  destination_cidr_block         = module.workload_vpc.vpc_cidr_block
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment.id
}

# Internet VPC: Route to Workload VPC via TGW
resource "aws_route" "internet_to_workload" {
  for_each               = { for i, id in module.internet_vpc.public_route_table_ids : tostring(i) => id }
  route_table_id         = each.value
  destination_cidr_block = module.workload_vpc.vpc_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment]
}

# Workload VPC: Route to Internet VPC via TGW
resource "aws_route" "workload_to_internet" {
  for_each               = { for i, id in module.workload_vpc.private_route_table_ids : tostring(i) => id }
  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment]
}
