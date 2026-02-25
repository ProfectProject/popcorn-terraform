# Helm Charts for EKS
# 설계 문서: .kiro/specs/terraform-infrastructure-refactoring/design.md

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_helm && var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  # 타임아웃 및 재시도 설정
  timeout         = 600
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller[0].arn
  }

  set {
    name  = "region"
    value = data.aws_region.current.name
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    aws_eks_node_group.main,
  ]
}

# Karpenter
resource "helm_release" "karpenter" {
  count = var.enable_helm && var.enable_karpenter ? 1 : 0

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  namespace  = "karpenter"
  version    = "1.9.0"

  create_namespace = true

  # 타임아웃 및 재시도 설정
  timeout         = 600
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter[0].arn
  }

  set {
    name  = "settings.clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = aws_eks_cluster.main.endpoint
  }

  set {
    name  = "settings.eksControlPlane"
    value = "true"
  }

  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter[0].name
  }

  # 운영 환경에서 Karpenter가 Karpenter 노드풀 노드에만 생성된 라벨(karpenter.sh/nodepool)이
  # 붙는 상태에서 기본 nodeAffinity(DoesNotExist)가 계속 남아 스케줄 실패가 반복되는 것을 방지한다.
  values = [
    yamlencode({
      affinity = {
        nodeAffinity = {}
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_sqs_queue.karpenter,
    aws_cloudwatch_event_rule.karpenter_spot_interruption,
  ]
}

# SQS Queue for Karpenter (Spot Interruption)
resource "aws_sqs_queue" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  name                      = "karpenter-${aws_eks_cluster.main.name}"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = var.tags
}

resource "aws_sqs_queue_policy" "karpenter" {
  count = var.enable_karpenter ? 1 : 0

  queue_url = aws_sqs_queue.karpenter[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter[0].arn
      }
    ]
  })
}

# EventBridge Rules for Karpenter
resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  count = var.enable_karpenter ? 1 : 0

  name        = "karpenter-spot-interruption-${aws_eks_cluster.main.name}"
  description = "Spot instance interruption warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  count = var.enable_karpenter ? 1 : 0

  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption[0].name
  target_id = "KarpenterQueue"
  arn       = aws_sqs_queue.karpenter[0].arn
}

resource "aws_cloudwatch_event_rule" "karpenter_scheduled_change" {
  count = var.enable_karpenter ? 1 : 0

  name        = "karpenter-scheduled-change-${aws_eks_cluster.main.name}"
  description = "EC2 scheduled maintenance"

  event_pattern = jsonencode({
    source      = ["aws.health"]
    detail-type = ["AWS Health Event"]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_scheduled_change" {
  count = var.enable_karpenter ? 1 : 0

  rule      = aws_cloudwatch_event_rule.karpenter_scheduled_change[0].name
  target_id = "KarpenterQueue"
  arn       = aws_sqs_queue.karpenter[0].arn
}

resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  count = var.enable_karpenter ? 1 : 0

  name        = "karpenter-instance-state-change-${aws_eks_cluster.main.name}"
  description = "EC2 instance state change"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["terminated", "stopping", "stopped"]
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  count = var.enable_karpenter ? 1 : 0

  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change[0].name
  target_id = "KarpenterQueue"
  arn       = aws_sqs_queue.karpenter[0].arn
}

# Metrics Server
resource "helm_release" "metrics_server" {
  count = var.enable_helm && var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  # 타임아웃 및 재시도 설정
  timeout         = 600
  wait            = true
  atomic          = true
  cleanup_on_fail = true

  set_list {
    name = "args"
    value = [
      "--cert-dir=/tmp",
      "--secure-port=4443",
      "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname",
      "--kubelet-use-node-status-port"
    ]
  }

  depends_on = [
    aws_eks_node_group.main,
  ]
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
