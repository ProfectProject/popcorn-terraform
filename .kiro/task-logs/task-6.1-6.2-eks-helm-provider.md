# Task 6.1 & 6.2: EKS Helm 설치 추가

## 작업 일시
2026-02-09

## 작업 내용

EKS 모듈에 Helm 및 Kubernetes provider를 추가하고, Helm 설치를 제어하는 `enable_helm` 변수를 추가했습니다.

## Task 6.1: EKS 모듈에 Helm provider 추가

### 생성된 파일
**파일**: `popcorn-terraform-feature/modules/eks/providers.tf`

```hcl
# Kubernetes Provider 설정
# EKS 클러스터 생성 후 자동으로 연결됩니다

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.main.name,
      "--region",
      var.region
    ]
  }
}

# Helm Provider 설정
# EKS 클러스터 생성 후 자동으로 연결됩니다

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.main.name,
        "--region",
        var.region
      ]
    }
  }
}
```

### Provider 설정 상세

#### Kubernetes Provider
- **인증 방식**: AWS EKS get-token (IAM 기반)
- **클러스터 엔드포인트**: EKS 클러스터 생성 후 자동 참조
- **CA 인증서**: EKS 클러스터의 CA 인증서 자동 디코딩

#### Helm Provider
- **인증 방식**: Kubernetes provider와 동일 (AWS EKS get-token)
- **클러스터 연결**: Kubernetes provider를 통해 EKS 클러스터 연결
- **버전**: Helm 3.x 사용

### 인증 흐름
```
Terraform
    ↓
AWS CLI (aws eks get-token)
    ↓
IAM 인증
    ↓
EKS 클러스터 엔드포인트
    ↓
Kubernetes API Server
    ↓
Helm Charts 배포
```

## Task 6.2: Helm 설치 리소스 추가

### 추가된 변수
**파일**: `popcorn-terraform-feature/modules/eks/variables.tf`

```hcl
variable "enable_helm" {
  description = "Helm 설치 여부 (모든 Helm 차트 설치를 제어하는 마스터 스위치)"
  type        = bool
  default     = true
}
```

### 수정된 Helm 리소스
**파일**: `popcorn-terraform-feature/modules/eks/helm.tf`

모든 Helm 리소스에 `enable_helm` 조건을 추가했습니다:

```hcl
# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_helm && var.enable_aws_load_balancer_controller ? 1 : 0
  # ...
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  count = var.enable_helm && var.enable_cluster_autoscaler ? 1 : 0
  # ...
}

# Metrics Server
resource "helm_release" "metrics_server" {
  count = var.enable_helm && var.enable_metrics_server ? 1 : 0
  # ...
}

# CloudWatch Container Insights
resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.enable_helm && var.enable_container_insights ? 1 : 0
  # ...
}

resource "kubernetes_config_map" "cwagentconfig" {
  count = var.enable_helm && var.enable_container_insights ? 1 : 0
  # ...
}

resource "helm_release" "cloudwatch_agent" {
  count = var.enable_helm && var.enable_container_insights ? 1 : 0
  # ...
}
```

### Helm 차트 제어 구조

#### 2단계 제어 시스템
1. **마스터 스위치**: `enable_helm` (모든 Helm 차트 설치 제어)
2. **개별 스위치**: `enable_aws_load_balancer_controller`, `enable_cluster_autoscaler` 등

#### 설치 조건
- `enable_helm = true` AND `enable_<chart> = true` → Helm 차트 설치
- `enable_helm = false` → 모든 Helm 차트 설치 안 함
- `enable_helm = true` AND `enable_<chart> = false` → 해당 Helm 차트만 설치 안 함

### 설치되는 Helm 차트 목록

#### 1. AWS Load Balancer Controller
- **목적**: ALB 및 NLB 자동 프로비저닝
- **제어 변수**: `enable_aws_load_balancer_controller`
- **기본값**: `true`

#### 2. Cluster Autoscaler
- **목적**: 노드 그룹 자동 스케일링
- **제어 변수**: `enable_cluster_autoscaler`
- **기본값**: `false` (Karpenter 사용 권장)

#### 3. Metrics Server
- **목적**: Kubernetes 메트릭 수집 (HPA 필수)
- **제어 변수**: `enable_metrics_server`
- **기본값**: `true`

#### 4. CloudWatch Container Insights
- **목적**: 컨테이너 로그 및 메트릭 수집
- **제어 변수**: `enable_container_insights`
- **기본값**: `true`

## 사용 방법

### Dev 환경 예제
**파일**: `popcorn-terraform-feature/envs/dev/main.tf`

```hcl
module "eks" {
  source = "../../modules/eks"

  name        = var.eks_name
  environment = "dev"
  region      = var.region
  vpc_id      = module.vpc.vpc_id

  # 네트워크 설정
  subnet_ids               = values(module.vpc.private_subnet_ids)
  control_plane_subnet_ids = values(module.vpc.public_subnet_ids)

  # 노드 그룹 설정
  node_group_instance_types = var.eks_node_instance_types
  node_group_capacity_type  = var.eks_node_capacity_type
  node_group_min_size       = var.eks_node_min_size
  node_group_max_size       = var.eks_node_max_size
  node_group_desired_size   = var.eks_node_desired_size

  # Kubernetes 버전
  cluster_version = var.eks_cluster_version

  # Helm 설치 활성화
  enable_helm = true

  # Add-ons 설정
  enable_aws_load_balancer_controller = true
  enable_karpenter                    = true
  enable_ebs_csi_driver               = true
  enable_metrics_server               = true
  enable_container_insights           = true

  tags = var.tags
}
```

### Helm 비활성화 예제
```hcl
module "eks" {
  source = "../../modules/eks"

  # ... 기본 설정 ...

  # 모든 Helm 차트 설치 비활성화
  enable_helm = false

  tags = var.tags
}
```

### 특정 Helm 차트만 비활성화 예제
```hcl
module "eks" {
  source = "../../modules/eks"

  # ... 기본 설정 ...

  # Helm 활성화
  enable_helm = true

  # Cluster Autoscaler만 비활성화 (Karpenter 사용)
  enable_aws_load_balancer_controller = true
  enable_cluster_autoscaler           = false  # 비활성화
  enable_karpenter                    = true
  enable_metrics_server               = true

  tags = var.tags
}
```

## 검증

### Terraform 검증
```bash
# EKS 모듈 검증
cd popcorn-terraform-feature/modules/eks
terraform init
terraform validate
terraform fmt -check
```

### Provider 연결 확인
```bash
# EKS 클러스터 생성 후
aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2

# Kubernetes 연결 확인
kubectl cluster-info
kubectl get nodes

# Helm 연결 확인
helm list -A
```

### Helm 차트 설치 확인
```bash
# AWS Load Balancer Controller 확인
kubectl get deployment -n kube-system aws-load-balancer-controller

# Metrics Server 확인
kubectl get deployment -n kube-system metrics-server

# CloudWatch Container Insights 확인
kubectl get daemonset -n amazon-cloudwatch
```

## 트러블슈팅

### 문제 1: Provider 인증 실패
**원인**: AWS CLI 자격증명 문제

**해결**:
```bash
# AWS 자격증명 확인
aws sts get-caller-identity

# EKS 클러스터 접근 권한 확인
aws eks describe-cluster --name <cluster-name> --region ap-northeast-2
```

### 문제 2: Helm 차트 설치 실패
**원인**: 
- EKS 노드 그룹이 아직 준비되지 않음
- IAM 역할 권한 부족

**해결**:
```bash
# 노드 상태 확인
kubectl get nodes

# Helm 릴리스 상태 확인
helm list -A

# Helm 릴리스 로그 확인
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### 문제 3: Provider 순환 참조
**원인**: EKS 클러스터와 Provider가 동시에 생성되려고 함

**해결**:
- `providers.tf`에서 EKS 클러스터 리소스를 참조하므로 자동으로 의존성 해결
- `depends_on`을 사용하여 명시적으로 의존성 지정

## 보안 고려사항

### IAM 인증
- AWS CLI를 통한 IAM 기반 인증 사용
- 임시 토큰 자동 갱신 (15분마다)
- 장기 자격증명 저장 불필요

### RBAC 권한
- Helm 차트는 각각 ServiceAccount 생성
- IRSA (IAM Roles for Service Accounts) 사용
- 최소 권한 원칙 적용

### 네트워크 보안
- EKS 클러스터 엔드포인트는 Private/Public 모드 선택 가능
- Kubernetes API 서버는 TLS 암호화
- Helm 차트 배포는 Kubernetes API를 통해 암호화된 통신

## 다음 단계

### Task 7.1: Dev 환경 워크플로우 작성
- `.github/workflows/terraform-dev.yml` 파일 생성
- PR 생성 시 terraform plan 실행
- PR 머지 시 terraform apply 실행

### Task 7.2: Prod 환경 워크플로우 작성
- `.github/workflows/terraform-prod.yml` 파일 생성
- 수동 승인 필요

## 참고사항

### Helm vs Kubernetes Manifest
- **Helm**: 패키지 관리, 버전 관리, 롤백 지원
- **Kubernetes Manifest**: 단순 리소스 정의

### Provider 설정 위치
- **모듈 내부** (`modules/eks/providers.tf`): 모듈이 자체적으로 provider 관리
- **루트 모듈** (`envs/dev/main.tf`): 루트에서 provider 전달

현재 구조는 모듈 내부에서 provider를 설정하여 모듈의 독립성을 유지합니다.

### Helm 차트 버전 관리
- 각 Helm 차트는 특정 버전으로 고정
- 버전 업그레이드 시 테스트 필요
- 호환성 확인 필수

## 결론

Task 6.1과 6.2가 완료되었습니다. EKS 모듈에 Kubernetes 및 Helm provider가 추가되었으며, `enable_helm` 변수를 통해 모든 Helm 차트 설치를 제어할 수 있습니다.

Provider는 EKS 클러스터 생성 후 자동으로 연결되며, AWS CLI를 통한 IAM 기반 인증을 사용합니다. 모든 Helm 차트는 2단계 제어 시스템 (마스터 스위치 + 개별 스위치)을 통해 세밀하게 관리할 수 있습니다.
