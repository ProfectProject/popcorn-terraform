#!/bin/bash

# Terraform State Cleanup Script
# 네트워크 문제로 destroy 실패한 리소스들을 state에서 제거

set -e

cd envs/dev

echo "🔧 Cleaning up Terraform state for failed resources..."

# 실패한 VPC Endpoints 제거
echo "Removing failed VPC Endpoints from state..."
terraform state rm 'module.vpc.aws_vpc_endpoint.interface["ec2messages"]' 2>/dev/null || true
terraform state rm 'module.vpc.aws_vpc_endpoint.interface["ecr_api"]' 2>/dev/null || true
terraform state rm 'module.vpc.aws_vpc_endpoint.interface["ecr_dkr"]' 2>/dev/null || true
terraform state rm 'module.vpc.aws_vpc_endpoint.interface["logs"]' 2>/dev/null || true
terraform state rm 'module.vpc.aws_vpc_endpoint.interface["secretsmanager"]' 2>/dev/null || true

# Internet Gateway 제거
echo "Removing Internet Gateway from state..."
terraform state rm 'module.vpc.aws_internet_gateway.this' 2>/dev/null || true

# 의존성 있는 Subnet 제거
echo "Removing problematic Subnet from state..."
terraform state rm 'module.vpc.aws_subnet.public["goorm-popcorn-dev-public-2a"]' 2>/dev/null || true
terraform state rm 'module.vpc.aws_subnet.private["goorm-popcorn-dev-private-2a"]' 2>/dev/null || true

# VPC 제거
echo "Removing VPC from state..."
terraform state rm 'module.vpc.aws_vpc.this' 2>/dev/null || true

# Security Groups 제거
echo "Removing Security Groups from state..."
terraform state rm 'module.vpc.aws_security_group.vpc_endpoints[0]' 2>/dev/null || true

echo "✅ Terraform state cleanup completed!"
echo "📝 You can now run 'terraform destroy' again or 'terraform plan' to see remaining resources."