# EKS Module Outputs

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = aws_eks_cluster.main.status
}

output "cluster_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_service_cidr" {
  description = "The CIDR block that Kubernetes pod and service IP addresses are assigned from"
  value       = aws_eks_cluster.main.kubernetes_network_config[0].service_ipv4_cidr
}

output "cluster_ip_family" {
  description = "The IP family used to assign Kubernetes pod and service addresses"
  value       = aws_eks_cluster.main.kubernetes_network_config[0].ip_family
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "The URL of the OIDC Provider"
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "node_groups" {
  description = "Map of attribute maps for all EKS node groups created"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      arn           = v.arn
      status        = v.status
      capacity_type = v.capacity_type
      instance_types = v.instance_types
      ami_type      = v.ami_type
      node_role_arn = v.node_role_arn
      scaling_config = v.scaling_config
      remote_access = v.remote_access
      labels        = v.labels
      taints        = v.taint
    }
  }
}

output "fargate_profiles" {
  description = "Map of attribute maps for all EKS Fargate profiles created"
  value = {
    for k, v in aws_eks_fargate_profile.main : k => {
      arn                    = v.arn
      status                 = v.status
      pod_execution_role_arn = v.pod_execution_role_arn
      selectors              = v.selector
    }
  }
}

output "cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value = {
    for k, v in aws_eks_addon.main : k => {
      arn               = v.arn
      status            = v.status
      addon_version     = v.addon_version
      resolve_conflicts = v.resolve_conflicts
    }
  }
}

output "node_group_iam_role_name" {
  description = "IAM role name for EKS node groups"
  value       = aws_iam_role.node_group.name
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN for EKS node groups"
  value       = aws_iam_role.node_group.arn
}

output "fargate_pod_execution_role_name" {
  description = "IAM role name for EKS Fargate pod execution"
  value       = aws_iam_role.fargate_pod.name
}

output "fargate_pod_execution_role_arn" {
  description = "IAM role ARN for EKS Fargate pod execution"
  value       = aws_iam_role.fargate_pod.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = var.enable_ebs_csi_driver ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key"
  value       = aws_kms_key.eks.arn
}

output "kms_key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = aws_kms_key.eks.key_id
}

output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = aws_cloudwatch_log_group.cluster.arn
}

output "security_group_arn" {
  description = "Amazon Resource Name (ARN) of the security group"
  value       = aws_security_group.cluster.arn
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.cluster.id
}

output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = aws_security_group.node_group.arn
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = aws_security_group.node_group.id
}