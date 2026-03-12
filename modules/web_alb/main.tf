
## ALB
resource "aws_lb" "workload_alb" {
  name               = var.alb_name
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.workload_alb_sg.id]
  subnets            = slice(var.private_subnet_ids, 0, 2)
}

resource "aws_security_group" "workload_alb_sg" {
  name        = "workload-alb-sg"
  description = "Security group for workload ALB"
  vpc_id      = var.vpc_id

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
  name        = var.target_group_name
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id


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
  target_group_arn = var.nlb_tg_arn
  target_id        = aws_lb.workload_alb.arn
  port             = 80

  depends_on = [aws_lb_listener.workload_alb_listener]
}