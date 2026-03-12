
#Application Load Balancer
resource "aws_lb" "internet_alb" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internet_alb_sg.id]
  subnets            = var.internet_public_subnet_ids
}

resource "aws_security_group" "internet_alb_sg" {
  name        = "internet-alb-sg"
  description = "public ALB security group"
  vpc_id      = var.internet_vpc_id

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
  name        = var.target_group_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.internet_vpc_id
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
    values = ["ELB net/${var.workload_nlb_name}/*"]
  }
  filter {
    name   = "status"
    values = ["in-use"]
  }
}

locals {
  # We define static keys ("az1", "az2") so Terraform knows 
  # how many resources to create before running.
  subnet_map = {
    "az1" = var.workload_vpc_private_subnet_ids[0]
    "az2" = var.workload_vpc_private_subnet_ids[1]
  }
}
# 2. Look up the ENI for each subnet
data "aws_network_interface" "nlb_eni_per_subnet" {
  for_each = local.subnet_map

  filter {
    name   = "description"
    values = ["ELB net/${var.workload_nlb_name}/*"]
  }

  filter {
    name   = "subnet-id"
    values = [each.value]
  }
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