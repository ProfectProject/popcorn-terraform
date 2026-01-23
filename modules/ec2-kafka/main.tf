# EC2 Kafka KRaft Cluster Module
# Supports both dev (single node) and prod (3 nodes) configurations

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  base_tags = merge({ Name = var.name }, var.tags)
}

# Data sources
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate cluster ID for KRaft
resource "random_uuid" "cluster_id" {}

# Kafka instances
resource "aws_instance" "kafka" {
  count = var.node_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [var.security_group_id]

  private_ip = length(var.private_ips) > 0 ? var.private_ips[count.index] : null

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    
    tags = merge(local.base_tags, {
      Name = "${var.name}-kafka-${var.environment}-${count.index + 1}-root"
    })
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_type = "gp3"
    volume_size = var.data_volume_size
    encrypted   = true
    iops        = var.data_volume_iops
    throughput  = var.data_volume_throughput

    tags = merge(local.base_tags, {
      Name = "${var.name}-kafka-${var.environment}-${count.index + 1}-data"
    })
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    node_id     = count.index + 1
    cluster_id  = random_uuid.cluster_id.result
    environment = var.environment
    node_count  = var.node_count
  }))

  iam_instance_profile = var.iam_instance_profile

  tags = merge(local.base_tags, {
    Name   = "${var.name}-kafka-${var.environment}-${count.index + 1}"
    Role   = "kafka"
    NodeId = count.index + 1
  })

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

# Route53 private hosted zone records for easy access
resource "aws_route53_record" "kafka" {
  count = var.create_dns_records ? var.node_count : 0

  zone_id = var.private_zone_id
  name    = "kafka-${var.environment}-${count.index + 1}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.kafka[count.index].private_ip]
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "kafka" {
  name              = "/aws/ec2/kafka-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(local.base_tags, {
    Name = "${var.name}-kafka-${var.environment}-logs"
  })
}