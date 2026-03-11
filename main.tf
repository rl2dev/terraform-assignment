provider "aws" {
  region = "us-east-1"
}
###############################
######## INTERNET VPC #########
###############################
module "internet_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "internet-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnet_names = ["gateway-subnet-a", "gateway-subnet-b"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  private_subnet_names = ["internet-tgw-subnet", "internet-firewall-subnet"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "internet-vpc"
  }
}

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


# Internet ALB Target Group - targets Workload ALB via TGW
resource "aws_lb_target_group" "internet_alb_tg" {
  name        = "internet-to-workload-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.internet_vpc.vpc_id
  target_type = "ip"

  # health_check {
  #   enabled             = true
  #   healthy_threshold   = 2
  #   interval            = 30
  #   matcher             = "200-399"
  #   path                = "/"
  #   port                = "traffic-port"
  #   protocol            = "HTTP"
  #   timeout             = 5
  #   unhealthy_threshold = 2
  # }
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

  azs              = ["us-east-1a", "us-east-1b"]
  private_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"] # tgw + web
  private_subnet_names = ["workload-web-subnet-a", "workload-web-subnet-b", "workload-tgw-subnet"]
  database_subnets = ["10.1.5.0/24", "10.1.6.0/24"] # db (requires 2 AZs)
  database_subnet_names = ["workload-db-subnet-a", "workload-db-subnet-b"]

  enable_nat_gateway = false # Will use TGW to reach internet

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "workload-vpc"
  }
}

## WEB RESOURCES ##

resource "aws_lb" "workload_nlb" {
  name               = "workload-vpc-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [module.workload_vpc.private_subnets[1]]

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

resource "aws_lb" "workload_alb" {
  name               = "workload-vpc-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.workload_alb_sg.id]
  subnets            = [module.workload_vpc.private_subnets[1], module.workload_vpc.intra_subnets[0]]
}

resource "aws_lb_target_group" "workload_alb_tg" {
  name        = "ecs-task-tg"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.workload_vpc.vpc_id


  #   health_check {
  #     enabled             = true
  #     healthy_threshold   = 2
  #     interval            = 30
  #     matcher             = "200"
  #     path                = "/"
  #     port                = "traffic-port"
  #     protocol            = "HTTP"
  #     timeout             = 5
  #     unhealthy_threshold = 2
  #   }
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


# NLB Target Group - targets Workload ALB
resource "aws_lb_target_group" "nlb_to_alb_tg" {
  name        = "nlb-to-alb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = module.workload_vpc.vpc_id
  target_type = "alb"

  # health_check {
  #   enabled             = true
  #   healthy_threshold   = 2
  #   interval            = 30
  #   port                = "traffic-port"
  #   protocol            = "HTTP"
  #   path                = "/"
  #   timeout             = 6
  #   unhealthy_threshold = 2
  # }
}

# Attach Workload ALB to NLB Target Group
resource "aws_lb_target_group_attachment" "nlb_to_alb" {
  target_group_arn = aws_lb_target_group.nlb_to_alb_tg.arn
  target_id        = aws_lb.workload_alb.arn
  port             = 80
}

# NLB Listener
resource "aws_lb_listener" "workload_nlb_listener" {
  load_balancer_arn = aws_lb.workload_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_to_alb_tg.arn
  }
}


### APP RESOURCES ###
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "7.4.0"

  cluster_name = "ecs-integrated"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }

  # Cluster capacity providers
  cluster_capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 50
      base   = 20
    }
    FARGATE_SPOT = {
      weight = 50
    }
  }
  services = {
    ecsdemo-frontend = {
      cpu    = 256
      memory = 512

      # Container definition(s)
      container_definitions = {
        ecs-sample = {
          essential = true
          image     = "k8s.gcr.io/e2e-test-images/echoserver:2.5"
          portMappings = [
            {
              name          = "ecs-sample"
              containerPort = 8080
              protocol      = "tcp"
            }
          ]
        }
      }

      load_balancer = {
        service = {
          target_group_arn = aws_lb_target_group.workload_alb_tg.arn
          container_name   = "ecs-sample"
          container_port   = 8080
        }
      }

      subnet_ids = module.workload_vpc.intra_subnets

      security_group_ingress_rules = {
        alb_ingress = {
          description                  = "Service port"
          from_port                    = 8080
          ip_protocol                  = "tcp"
          referenced_security_group_id = aws_security_group.workload_alb_sg.id
        }
      }
      security_group_egress_rules = {
        all = {
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }
    }
  }

  tags = {
    Environment = "Development"
    Project     = "Example"
  }
}

### TRANSIT GATEWAY ###
resource "aws_ec2_transit_gateway" "transit_gateway" {
  description = "transit gateway for internet and workload VPCs"
}

resource "aws_ec2_transit_gateway_vpc_attachment" "internet_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = module.internet_vpc.vpc_id
  subnet_ids         = module.internet_vpc.private_subnets
}

resource "aws_ec2_transit_gateway_vpc_attachment" "workload_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.transit_gateway.id
  vpc_id             = module.workload_vpc.vpc_id
  subnet_ids         = [module.workload_vpc.private_subnets[0]]
}

### ROUTE TABLES ###

# Internet VPC: Route to Workload VPC via TGW
resource "aws_route" "internet_to_workload" {
  route_table_id         = module.internet_vpc.public_route_table_ids[0]
  destination_cidr_block = module.workload_vpc.vpc_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.internet_vpc_attachment]
}

# Workload VPC: Route to Internet VPC via TGW
resource "aws_route" "workload_to_internet" {
  route_table_id         = module.workload_vpc.private_route_table_ids[0]
  destination_cidr_block = module.internet_vpc.vpc_cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment]
}

# Workload VPC: Default route to Internet via TGW (for outbound)
resource "aws_route" "workload_to_internet_default" {
  route_table_id         = module.workload_vpc.private_route_table_ids[0]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment]
}

# Workload intra subnets also need routes
resource "aws_route" "workload_intra_to_internet" {
  route_table_id         = module.workload_vpc.intra_route_table_ids[0]
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gateway.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.workload_vpc_attachment]
}
