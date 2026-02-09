# EKS Configuration for Development Environment
# 6-12개월 후 ECS에서 EKS로 전환을 위한 설정
# 현재는 비활성화 상태 (enable_eks = false)

# EKS 모듈 호출
# 주의: EKS 모듈에 provider 설정이 있어 count를 사용할 수 없습니다
# EKS를 활성화하려면 아래 주석을 해제하고 enable_eks 변수를 제거하세요
/*
module "eks" {
  source = "../../modules/eks"

  cluster_name       = "${var.project_name}-${var.environment}-eks"
  environment        = var.environment
  kubernetes_version = "1.31"

  # 네트워크 설정
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = concat(values(module.vpc.public_subnet_ids), values(module.vpc.private_subnet_ids))
  private_subnet_ids = values(module.vpc.private_subnet_ids)

  # API 엔드포인트 설정
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["0.0.0.0/0"]

  # 로깅 설정
  cluster_log_types        = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_retention = 7
  kms_key_deletion_window  = 7

  # Node Groups 설정
  node_groups = {
    # 일반 워크로드용 노드 그룹
    general = {
      capacity_type              = "ON_DEMAND"
      instance_types             = ["t3.medium"]
      ami_type                   = "AL2_x86_64"
      disk_size                  = 20
      desired_size               = 2
      max_size                   = 5
      min_size                   = 1
      max_unavailable_percentage = 25
      labels = {
        role        = "general"
        environment = var.environment
      }
      taints = []
    }

    # 스팟 인스턴스 노드 그룹 (비용 절감)
    spot = {
      capacity_type              = "SPOT"
      instance_types             = ["t3.medium", "t3.large"]
      ami_type                   = "AL2_x86_64"
      disk_size                  = 20
      desired_size               = 1
      max_size                   = 3
      min_size                   = 0
      max_unavailable_percentage = 50
      labels = {
        role        = "spot"
        environment = var.environment
      }
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  # Fargate 프로필 (서버리스 워크로드용)
  fargate_profiles = {
    default = {
      selectors = [
        {
          namespace = "kube-system"
          labels    = {}
        },
        {
          namespace = "default"
          labels    = {}
        }
      ]
    }
  }

  # 클러스터 애드온
  cluster_addons = {
    coredns = {
      version                  = "v1.11.3-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    }
    kube-proxy = {
      version                  = "v1.31.0-eksbuild.5"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    }
    vpc-cni = {
      version                  = "v1.18.5-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    }
    aws-ebs-csi-driver = {
      version                  = "v1.35.0-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    }
  }

  # 추가 기능 활성화
  enable_aws_load_balancer_controller = true
  enable_ebs_csi_driver               = true
  enable_cluster_autoscaler           = true
  enable_metrics_server               = true
  enable_container_insights           = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Purpose     = "eks-migration-preparation"
  }
}
*/

# EKS 출력 (현재 비활성화)
/*
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "eks_node_groups" {
  description = "EKS node groups"
  value       = module.eks.node_groups
}
*/