# EKS Cluster Module
# Kubernetes 1.35 기반 EKS 클러스터

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.control_plane_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = var.cluster_log_types

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = merge(var.tags, {
    Name = var.name
  })
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name}-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids

  capacity_type  = var.node_group_capacity_type
  instance_types = var.node_group_instance_types
  ami_type       = "AL2_x86_64"
  disk_size      = 20

  scaling_config {
    desired_size = var.node_group_desired_size
    max_size     = var.node_group_max_size
    min_size     = var.node_group_min_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  # Kubernetes labels
  labels = {
    "node-group"  = "${var.name}-nodes"
    "environment" = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = merge(var.tags, {
    Name = "${var.name}-nodes"
  })
}

# EKS Add-ons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  
  depends_on = [aws_eks_node_group.main]
  tags = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  
  depends_on = [aws_eks_node_group.main]
  tags = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  
  depends_on = [aws_eks_node_group.main]
  tags = var.tags
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver[0].arn
  
  depends_on = [aws_eks_node_group.main]
  tags = var.tags
}

# KMS Key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name}-eks-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.name}-eks-encryption-key"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.cloudwatch_log_retention
  kms_key_id        = aws_kms_key.eks.arn

  tags = merge(var.tags, {
    Name = "${var.name}-cluster-logs"
  })
}

# CloudWatch Logs → Loki 통합을 위한 IAM 역할
resource "aws_iam_role" "cloudwatch_logs_role" {
  count = var.enable_loki_integration ? 1 : 0
  name  = "${var.name}-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudwatch_logs_policy" {
  count = var.enable_loki_integration ? 1 : 0
  name  = "${var.name}-cloudwatch-logs-policy"
  role  = aws_iam_role.cloudwatch_logs_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.eks_logs[0].arn
      }
    ]
  })
}

# Kinesis Stream for EKS logs
resource "aws_kinesis_stream" "eks_logs" {
  count           = var.enable_loki_integration ? 1 : 0
  name            = "${var.name}-eks-logs-stream"
  shard_count     = 1
  retention_period = 24

  tags = var.tags
}

# CloudWatch Logs Subscription Filter
resource "aws_cloudwatch_log_subscription_filter" "eks_logs_to_kinesis" {
  count           = var.enable_loki_integration ? 1 : 0
  name            = "${var.name}-eks-logs-filter"
  log_group_name  = aws_cloudwatch_log_group.cluster.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_stream.eks_logs[0].arn
  role_arn        = aws_iam_role.cloudwatch_logs_role[0].arn

  depends_on = [aws_iam_role_policy.cloudwatch_logs_policy]
}

# Security Group for EKS Cluster
resource "aws_security_group" "cluster" {
  name_prefix = "${var.name}-cluster-"
  vpc_id      = var.vpc_id
  description = "EKS cluster security group"

  tags = merge(var.tags, {
    Name = "${var.name}-cluster-sg"
  })
}

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.public_access_cidrs
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_egress_all" {
  description       = "Allow cluster egress access to the Internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# Security Group for EKS Node Groups
resource "aws_security_group" "node_group" {
  name_prefix = "${var.name}-node-group-"
  vpc_id      = var.vpc_id
  description = "EKS node group security group"

  tags = merge(var.tags, {
    Name = "${var.name}-node-group-sg"
  })
}

resource "aws_security_group_rule" "node_group_ingress_self" {
  description              = "Allow node to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_ingress_cluster_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "node_group_egress_all" {
  description       = "Allow node group egress access to the Internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_group.id
}

resource "aws_security_group_rule" "cluster_ingress_node_group_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group.id
  security_group_id        = aws_security_group.cluster.id
}