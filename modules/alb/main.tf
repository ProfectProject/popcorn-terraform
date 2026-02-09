# ALB 리소스 정의
resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = var.internal

  subnets         = var.subnet_ids
  security_groups = var.security_group_ids

  # 액세스 로그 설정 (선택적)
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = var.tags
}

# Default Target Group (EKS Ingress Controller가 관리)
resource "aws_lb_target_group" "default" {
  name        = var.target_group_name != null ? var.target_group_name : "${var.name}-default"
  port        = var.target_group_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = var.tags
}

# 추가 타겟 그룹 (Host-based 라우팅용)
resource "aws_lb_target_group" "additional" {
  count = length(var.target_groups)

  name        = var.target_groups[count.index].name
  port        = var.target_groups[count.index].port
  protocol    = var.target_groups[count.index].protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = var.target_groups[count.index].health_check.path
    interval            = var.target_groups[count.index].health_check.interval
    timeout             = var.target_groups[count.index].health_check.timeout
    healthy_threshold   = var.target_groups[count.index].health_check.healthy_threshold
    unhealthy_threshold = var.target_groups[count.index].health_check.unhealthy_threshold
    matcher             = var.target_groups[count.index].health_check.matcher
  }

  tags = var.tags
}

# HTTP 리스너 (HTTPS로 리다이렉트)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS 리스너 (ACM 인증서 사용)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

# 리스너 규칙 (Host-based 라우팅)
resource "aws_lb_listener_rule" "host_based" {
  count = length(var.listener_rules)

  listener_arn = aws_lb_listener.https.arn
  priority     = var.listener_rules[count.index].priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.additional[var.listener_rules[count.index].target_group_index].arn
  }

  condition {
    host_header {
      values = [var.listener_rules[count.index].host_header]
    }
  }

  tags = var.tags
}
