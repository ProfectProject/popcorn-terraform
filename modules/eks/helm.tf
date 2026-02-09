# Helm Charts and Kubernetes Resources for EKS

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_helm && var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

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

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  count = var.enable_helm && var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.37.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "awsRegion"
    value = data.aws_region.current.name
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler[0].arn
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"
  }

  set {
    name  = "extraArgs.skip-nodes-with-local-storage"
    value = "false"
  }

  depends_on = [
    aws_eks_node_group.main,
  ]
}

# Metrics Server
resource "helm_release" "metrics_server" {
  count = var.enable_helm && var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  set {
    name  = "args[0]"
    value = "--cert-dir=/tmp"
  }

  set {
    name  = "args[1]"
    value = "--secure-port=4443"
  }

  set {
    name  = "args[2]"
    value = "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"
  }

  set {
    name  = "args[3]"
    value = "--kubelet-use-node-status-port"
  }

  depends_on = [
    aws_eks_node_group.main,
  ]
}

# CloudWatch Container Insights
resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.enable_helm && var.enable_container_insights ? 1 : 0

  metadata {
    name = "amazon-cloudwatch"
    labels = {
      name = "amazon-cloudwatch"
    }
  }

  depends_on = [aws_eks_cluster.main]
}

resource "kubernetes_config_map" "cwagentconfig" {
  count = var.enable_helm && var.enable_container_insights ? 1 : 0

  metadata {
    name      = "cwagentconfig"
    namespace = kubernetes_namespace.amazon_cloudwatch[0].metadata[0].name
  }

  data = {
    "cwagentconfig.json" = jsonencode({
      logs = {
        metrics_collected = {
          kubernetes = {
            cluster_name = aws_eks_cluster.main.name
            metrics_collection_interval = 60
          }
        }
        force_flush_interval = 5
      }
    })
  }

  depends_on = [kubernetes_namespace.amazon_cloudwatch]
}

resource "helm_release" "cloudwatch_agent" {
  count = var.enable_helm && var.enable_container_insights ? 1 : 0

  name       = "cloudwatch-agent"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-cloudwatch-metrics"
  namespace  = kubernetes_namespace.amazon_cloudwatch[0].metadata[0].name
  version    = "0.0.11"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  depends_on = [
    aws_eks_node_group.main,
    kubernetes_config_map.cwagentconfig,
  ]
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}