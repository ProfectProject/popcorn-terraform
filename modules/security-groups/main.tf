# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Security Group
resource "aws_security_group" "ecs" {
  name_prefix = "${var.project_name}-ecs-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Kafka broker"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Aurora Security Group
resource "aws_security_group" "aurora" {
  name_prefix = "${var.project_name}-aurora-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-aurora-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ElastiCache Security Group
resource "aws_security_group" "elasticache" {
  name_prefix = "${var.project_name}-elasticache-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-elasticache-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# MSK Serverless Security Group
resource "aws_security_group" "msk" {
  name_prefix = "${var.project_name}-msk-"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MSK IAM from ECS"
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-msk-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Kafka KRaft Security Group
resource "aws_security_group" "kafka" {
  name_prefix = "${var.project_name}-kafka-"
  vpc_id      = var.vpc_id

  # Kafka broker port from ECS
  ingress {
    description     = "Kafka broker from ECS"
    from_port       = 9092
    to_port         = 9092
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  # Kafka controller port (cluster internal communication)
  ingress {
    description = "Kafka controller (cluster internal)"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    self        = true
  }

  # JMX monitoring port (optional)
  ingress {
    description = "JMX monitoring"
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
  }

  # SSH access (optional, for debugging)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-kafka-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}