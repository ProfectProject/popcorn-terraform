#!/bin/bash

# EKS 클러스터 활성화 스크립트
# 6-12개월 후 ECS에서 EKS로 마이그레이션을 위한 준비

set -e

ENVIRONMENT=${1:-dev}
REGION="ap-northeast-2"

echo "🚀 Enabling EKS cluster for ${ENVIRONMENT} environment..."

# 1. 현재 디렉토리 확인
if [[ ! -f "envs/${ENVIRONMENT}/terraform.tfvars" ]]; then
    echo "❌ terraform.tfvars not found in envs/${ENVIRONMENT}/"
    echo "Please run this script from the terraform root directory"
    exit 1
fi

# 2. EKS 활성화 설정
echo "📝 Updating terraform.tfvars to enable EKS..."
cd envs/${ENVIRONMENT}

# enable_eks 변수가 이미 있는지 확인
if grep -q "enable_eks" terraform.tfvars; then
    sed -i '' 's/enable_eks = false/enable_eks = true/' terraform.tfvars
else
    echo "" >> terraform.tfvars
    echo "# EKS Configuration" >> terraform.tfvars
    echo "enable_eks = true" >> terraform.tfvars
fi

echo "✅ EKS enabled in terraform.tfvars"

# 3. Terraform 계획 확인
echo "📋 Planning EKS deployment..."
terraform plan -target=module.eks

# 4. 사용자 확인
read -p "Do you want to proceed with EKS deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ EKS deployment cancelled"
    exit 1
fi

# 5. EKS 배포
echo "🏗️  Deploying EKS cluster..."
terraform apply -target=module.eks -auto-approve

# 6. EKS 클러스터 정보 가져오기
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
CLUSTER_ENDPOINT=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "")

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "❌ Failed to get EKS cluster information"
    exit 1
fi

echo "✅ EKS cluster deployed successfully!"
echo "   Cluster Name: $CLUSTER_NAME"
echo "   Endpoint: $CLUSTER_ENDPOINT"

# 7. kubectl 설정
echo "🔧 Configuring kubectl..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# 8. 클러스터 상태 확인
echo "🔍 Checking cluster status..."
kubectl get nodes
kubectl get pods --all-namespaces

# 9. 네임스페이스 생성
echo "📦 Creating application namespaces..."
kubectl create namespace popcorn-app --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace popcorn-monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace popcorn-logging --dry-run=client -o yaml | kubectl apply -f -

# 10. 기본 라벨 추가
kubectl label namespace popcorn-app environment=${ENVIRONMENT} --overwrite
kubectl label namespace popcorn-monitoring environment=${ENVIRONMENT} --overwrite
kubectl label namespace popcorn-logging environment=${ENVIRONMENT} --overwrite

echo ""
echo "🎉 EKS cluster setup completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Review the EKS Migration Guide: docs/EKS_MIGRATION_GUIDE.md"
echo "2. Install monitoring stack: helm install prometheus..."
echo "3. Create Kubernetes manifests for your services"
echo "4. Set up CI/CD pipeline for EKS deployment"
echo ""
echo "📊 Cluster Information:"
echo "   kubectl get nodes"
echo "   kubectl get pods --all-namespaces"
echo "   kubectl config current-context"
echo ""
echo "🔗 Useful Commands:"
echo "   kubectl get svc -n kube-system"
echo "   kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
echo "   kubectl describe nodes"

cd ../..
echo "✅ Script completed successfully!"