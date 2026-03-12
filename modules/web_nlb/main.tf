
## NLB
resource "aws_lb" "workload_nlb" {
  name               = var.nlb_name
  internal           = true
  load_balancer_type = "network"
  subnets            = slice(var.private_subnet_ids, 0, 2)
}

# NLB Target Group - targets Workload ALB
resource "aws_lb_target_group" "nlb_tg" {
  name        = "nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
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