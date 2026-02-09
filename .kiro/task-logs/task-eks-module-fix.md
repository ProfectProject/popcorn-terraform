# EKS 모듈 문제 해결

## 작업 일시
2026-02-09

## 문제 설명

EKS 모듈에서 두 가지 문제가 발견되었습니다:

1. **Fargate Profile 참조 오류**: `helm.tf`의 `depends_on` 블록에서 `aws_eks_fargate_profile.main`을 참조하지만, 이 리소스가 `main.tf`에 정의되어 있지 않음
2. **Cluster Autoscaler IAM Role 누락**: `helm.tf`에서 `aws_iam_role.cluster_autoscaler[0].arn`을 참조하지만, 이 IAM 역할이 `iam.tf`에 정의되어 있지 않음

## 해결 방법

### 1. Fargate Profile 참조 제거

**파일**: `popcorn-terraform-feature/modules/eks/helm.tf`

다음 리소스의 `depends_on` 블록에서 `aws_eks_fargate_profile.main` 참조를 제거했습니다:
- `helm_release.aws_load_balancer_controller`
- `helm_release.cluster_autoscaler`
- `helm_release.metrics_server`

**변경 전**:
```hcl
depends_on = [
  aws_eks_node_group.main,
  aws_eks_fargate_profile.main,
]
```

**변경 후**:
```hcl
depends_on = [
  aws_eks_node_group.main,
]
```

### 2. Cluster Autoscaler IAM Role 추가

**파일**: `popcorn-terraform-feature/modules/eks/iam.tf`

Cluster Autoscaler를 위한 IAM 역할 및 정책을 추가했습니다:

```hcl
# Cluster Autoscaler IAM Role
resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  name  = "${var.name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name}-cluster-autoscaler"
  })
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  name  = "${var.name}-cluster-autoscaler"
  role  = aws_iam_role.cluster_autoscaler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeImages",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## 검증

### Terraform Validate 실행

```bash
cd popcorn-terraform-feature/modules/eks
terraform init
terraform validate
```

**예상 결과**: 모든 검증 통과

## 영향 범위

- **EKS 모듈**: Fargate Profile 의존성 제거로 인해 Helm 차트 배포가 Node Group에만 의존하게 됨
- **Cluster Autoscaler**: IAM 역할이 추가되어 Cluster Autoscaler가 정상적으로 작동할 수 있음
- **환경별 설정**: Dev 및 Prod 환경 모두 영향 없음 (변수 설정만 필요)

## 다음 단계

1. Task 2.2: Security Groups 모듈 README.md 작성
2. Task 2.3: Security Groups 모듈 단위 테스트 실행
3. Task 5.1 이후 작업 계속 진행

## 참고사항

- Fargate Profile은 현재 프로젝트에서 사용하지 않으므로 제거해도 문제없음
- Cluster Autoscaler는 `enable_cluster_autoscaler` 변수로 제어되며, 기본값은 `false`
- Karpenter를 주로 사용하므로 Cluster Autoscaler는 선택적으로 활성화 가능
