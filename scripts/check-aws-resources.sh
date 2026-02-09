#!/bin/bash
# AWS 리소스 확인 스크립트

echo "=== AWS 배포 준비 상태 확인 ==="
echo ""

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. S3 백엔드 버킷 확인
echo "1. S3 백엔드 버킷 확인"
if aws s3 ls s3://goorm-popcorn-tfstate 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Dev 환경 S3 버킷 존재: goorm-popcorn-tfstate"
else
  echo -e "${RED}✗${NC} Dev 환경 S3 버킷 없음: goorm-popcorn-tfstate"
fi

if aws s3 ls s3://popcorn-terraform-state 2>/dev/null; then
  echo -e "${GREEN}✓${NC} Prod 환경 S3 버킷 존재: popcorn-terraform-state"
else
  echo -e "${RED}✗${NC} Prod 환경 S3 버킷 없음: popcorn-terraform-state"
fi
echo ""

# 2. DynamoDB 테이블 확인
echo "2. DynamoDB 테이블 확인"
if aws dynamodb describe-table --table-name goorm-popcorn-tfstate-lock --region ap-northeast-2 2>/dev/null | grep -q "TableName"; then
  echo -e "${GREEN}✓${NC} Dev 환경 DynamoDB 테이블 존재: goorm-popcorn-tfstate-lock"
else
  echo -e "${RED}✗${NC} Dev 환경 DynamoDB 테이블 없음: goorm-popcorn-tfstate-lock"
fi

if aws dynamodb describe-table --table-name popcorn-terraform-state-lock --region ap-northeast-2 2>/dev/null | grep -q "TableName"; then
  echo -e "${GREEN}✓${NC} Prod 환경 DynamoDB 테이블 존재: popcorn-terraform-state-lock"
else
  echo -e "${RED}✗${NC} Prod 환경 DynamoDB 테이블 없음: popcorn-terraform-state-lock"
fi
echo ""

# 3. Route53 호스팅 존 확인
echo "3. Route53 호스팅 존 확인"
HOSTED_ZONE=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='goormpopcorn.shop.'].Id" --output text 2>/dev/null)
if [ -n "$HOSTED_ZONE" ]; then
  echo -e "${GREEN}✓${NC} Route53 호스팅 존 존재: goormpopcorn.shop"
  echo "  Zone ID: $HOSTED_ZONE"
else
  echo -e "${RED}✗${NC} Route53 호스팅 존 없음: goormpopcorn.shop"
fi
echo ""

# 4. ACM 인증서 확인
echo "4. ACM 인증서 확인"
CERT_ARN=$(aws acm list-certificates --region ap-northeast-2 --query "CertificateSummaryList[?DomainName=='goormpopcorn.shop'].CertificateArn" --output text 2>/dev/null)
if [ -n "$CERT_ARN" ]; then
  CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region ap-northeast-2 --query "Certificate.Status" --output text 2>/dev/null)
  if [ "$CERT_STATUS" == "ISSUED" ]; then
    echo -e "${GREEN}✓${NC} ACM 인증서 발급 완료: goormpopcorn.shop"
    echo "  ARN: $CERT_ARN"
  else
    echo -e "${YELLOW}⚠${NC} ACM 인증서 상태: $CERT_STATUS"
    echo "  ARN: $CERT_ARN"
  fi
else
  echo -e "${RED}✗${NC} ACM 인증서 없음: goormpopcorn.shop"
fi
echo ""

# 5. ECR 리포지토리 확인
echo "5. ECR 리포지토리 확인"
ECR_REPOS=$(aws ecr describe-repositories --region ap-northeast-2 --query "repositories[?contains(repositoryName, 'popcorn')].repositoryName" --output text 2>/dev/null)
if [ -n "$ECR_REPOS" ]; then
  echo -e "${GREEN}✓${NC} ECR 리포지토리 존재:"
  echo "$ECR_REPOS" | tr '\t' '\n' | sed 's/^/  - /'
else
  echo -e "${RED}✗${NC} ECR 리포지토리 없음"
fi
echo ""

# 6. 기존 VPC 확인
echo "6. 기존 VPC 확인 (popcorn 프로젝트)"
EXISTING_VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=popcorn" --query "Vpcs[].VpcId" --output text --region ap-northeast-2 2>/dev/null)
if [ -n "$EXISTING_VPCS" ]; then
  echo -e "${YELLOW}⚠${NC} 기존 VPC 존재:"
  echo "$EXISTING_VPCS" | tr '\t' '\n' | sed 's/^/  - /'
else
  echo -e "${GREEN}✓${NC} 기존 VPC 없음 (새로 생성 가능)"
fi
echo ""

# 7. 기존 EKS 클러스터 확인
echo "7. 기존 EKS 클러스터 확인"
EXISTING_CLUSTERS=$(aws eks list-clusters --region ap-northeast-2 --query "clusters" --output text 2>/dev/null)
if [ -n "$EXISTING_CLUSTERS" ]; then
  echo -e "${YELLOW}⚠${NC} 기존 EKS 클러스터 존재:"
  echo "$EXISTING_CLUSTERS" | tr '\t' '\n' | sed 's/^/  - /'
else
  echo -e "${GREEN}✓${NC} 기존 EKS 클러스터 없음 (새로 생성 가능)"
fi
echo ""

# 8. 서비스 제한 확인
echo "8. 서비스 제한 확인"
echo -e "${YELLOW}⚠${NC} 주요 서비스 제한을 확인하세요:"
echo "  - VPC: https://console.aws.amazon.com/servicequotas/home/services/vpc/quotas"
echo "  - EKS: https://console.aws.amazon.com/servicequotas/home/services/eks/quotas"
echo "  - RDS: https://console.aws.amazon.com/servicequotas/home/services/rds/quotas"
echo ""

# 요약
echo "=== 배포 준비 상태 요약 ==="
echo ""
echo "다음 단계:"
echo "1. 누락된 리소스가 있다면 bootstrap 디렉터리에서 생성"
echo "2. terraform.tfvars 파일 설정"
echo "3. terraform init 및 plan 실행"
echo "4. 문제 없으면 terraform apply 실행"
echo ""
