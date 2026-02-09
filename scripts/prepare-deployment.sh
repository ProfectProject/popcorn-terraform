#!/bin/bash
# 배포 준비 스크립트

set -e

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Terraform 배포 준비 스크립트 ===${NC}"
echo ""

# 환경 선택
if [ -z "$ENV" ]; then
  echo "환경을 선택하세요:"
  echo "1) dev"
  echo "2) prod"
  read -p "선택 (1 또는 2): " choice
  
  case $choice in
    1) ENV="dev" ;;
    2) ENV="prod" ;;
    *) echo -e "${RED}잘못된 선택입니다${NC}"; exit 1 ;;
  esac
fi

echo -e "${GREEN}선택된 환경: $ENV${NC}"
echo ""

# 1. AWS 자격증명 확인
echo -e "${YELLOW}1. AWS 자격증명 확인${NC}"
if aws sts get-caller-identity > /dev/null 2>&1; then
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
  echo -e "${GREEN}✓${NC} AWS 자격증명 확인 완료"
  echo "  Account ID: $ACCOUNT_ID"
  echo "  User: $USER_ARN"
else
  echo -e "${RED}✗${NC} AWS 자격증명 오류"
  echo "  aws configure를 실행하여 자격증명을 설정하세요"
  exit 1
fi
echo ""

# 2. S3 백엔드 확인
echo -e "${YELLOW}2. S3 백엔드 확인${NC}"
if [ "$ENV" == "dev" ]; then
  BUCKET_NAME="goorm-popcorn-tfstate"
else
  BUCKET_NAME="popcorn-terraform-state"
fi

if aws s3 ls s3://$BUCKET_NAME 2>/dev/null; then
  echo -e "${GREEN}✓${NC} S3 버킷 존재: $BUCKET_NAME"
else
  echo -e "${RED}✗${NC} S3 버킷 없음: $BUCKET_NAME"
  read -p "S3 버킷을 생성하시겠습니까? (y/n): " create_bucket
  if [ "$create_bucket" == "y" ]; then
    aws s3 mb s3://$BUCKET_NAME --region ap-northeast-2
    aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
    echo -e "${GREEN}✓${NC} S3 버킷 생성 완료"
  else
    echo -e "${RED}배포를 계속할 수 없습니다${NC}"
    exit 1
  fi
fi
echo ""

# 3. DynamoDB 테이블 확인
echo -e "${YELLOW}3. DynamoDB 테이블 확인${NC}"
TABLE_NAME="${BUCKET_NAME}-lock"

if aws dynamodb describe-table --table-name $TABLE_NAME --region ap-northeast-2 2>/dev/null | grep -q "TableName"; then
  echo -e "${GREEN}✓${NC} DynamoDB 테이블 존재: $TABLE_NAME"
else
  echo -e "${RED}✗${NC} DynamoDB 테이블 없음: $TABLE_NAME"
  read -p "DynamoDB 테이블을 생성하시겠습니까? (y/n): " create_table
  if [ "$create_table" == "y" ]; then
    aws dynamodb create-table \
      --table-name $TABLE_NAME \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region ap-northeast-2
    echo -e "${GREEN}✓${NC} DynamoDB 테이블 생성 완료"
  else
    echo -e "${RED}배포를 계속할 수 없습니다${NC}"
    exit 1
  fi
fi
echo ""

# 4. Route53 및 ACM 확인
echo -e "${YELLOW}4. Route53 및 ACM 확인${NC}"
HOSTED_ZONE=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='goormpopcorn.shop.'].Id" --output text 2>/dev/null | cut -d'/' -f3)
if [ -n "$HOSTED_ZONE" ]; then
  echo -e "${GREEN}✓${NC} Route53 호스팅 존 존재"
  echo "  Zone ID: $HOSTED_ZONE"
else
  echo -e "${RED}✗${NC} Route53 호스팅 존 없음"
fi

CERT_ARN=$(aws acm list-certificates --region ap-northeast-2 --query "CertificateSummaryList[?DomainName=='goormpopcorn.shop'].CertificateArn" --output text 2>/dev/null)
if [ -n "$CERT_ARN" ]; then
  CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region ap-northeast-2 --query "Certificate.Status" --output text 2>/dev/null)
  echo -e "${GREEN}✓${NC} ACM 인증서 상태: $CERT_STATUS"
  echo "  ARN: $CERT_ARN"
else
  echo -e "${RED}✗${NC} ACM 인증서 없음"
fi
echo ""

# 5. terraform.tfvars 파일 확인
echo -e "${YELLOW}5. terraform.tfvars 파일 확인${NC}"
TFVARS_FILE="envs/$ENV/terraform.tfvars"

if [ -f "$TFVARS_FILE" ]; then
  echo -e "${GREEN}✓${NC} terraform.tfvars 파일 존재"
  
  # 중요 변수 확인
  if grep -q "CHANGE_ME" "$TFVARS_FILE"; then
    echo -e "${RED}✗${NC} terraform.tfvars에 CHANGE_ME 값이 있습니다"
    echo "  파일을 편집하여 실제 값으로 변경하세요"
    exit 1
  fi
  
  if grep -q "YOUR_OFFICE_IP" "$TFVARS_FILE"; then
    echo -e "${YELLOW}⚠${NC} terraform.tfvars에 YOUR_OFFICE_IP 값이 있습니다"
    echo "  화이트리스트 IP를 실제 값으로 변경하세요"
  fi
else
  echo -e "${RED}✗${NC} terraform.tfvars 파일 없음"
  echo "  terraform.tfvars.example을 복사하여 terraform.tfvars를 생성하세요"
  exit 1
fi
echo ""

# 6. Terraform 초기화
echo -e "${YELLOW}6. Terraform 초기화${NC}"
cd "envs/$ENV"

if terraform init -upgrade; then
  echo -e "${GREEN}✓${NC} Terraform 초기화 완료"
else
  echo -e "${RED}✗${NC} Terraform 초기화 실패"
  exit 1
fi
echo ""

# 7. Terraform Validate
echo -e "${YELLOW}7. Terraform Validate${NC}"
if terraform validate; then
  echo -e "${GREEN}✓${NC} Terraform 검증 통과"
else
  echo -e "${RED}✗${NC} Terraform 검증 실패"
  exit 1
fi
echo ""

# 8. Terraform Plan
echo -e "${YELLOW}8. Terraform Plan 실행${NC}"
echo "Plan을 실행하시겠습니까? (시간이 걸릴 수 있습니다)"
read -p "계속하시겠습니까? (y/n): " run_plan

if [ "$run_plan" == "y" ]; then
  if terraform plan -out=${ENV}.tfplan; then
    echo -e "${GREEN}✓${NC} Terraform Plan 완료"
    echo ""
    echo -e "${BLUE}Plan 파일이 생성되었습니다: ${ENV}.tfplan${NC}"
    echo ""
    echo "다음 명령으로 배포할 수 있습니다:"
    echo -e "${GREEN}  cd envs/$ENV${NC}"
    echo -e "${GREEN}  terraform apply ${ENV}.tfplan${NC}"
  else
    echo -e "${RED}✗${NC} Terraform Plan 실패"
    exit 1
  fi
else
  echo "Plan을 건너뛰었습니다"
fi
echo ""

# 9. 배포 준비 완료
echo -e "${BLUE}=== 배포 준비 완료 ===${NC}"
echo ""
echo "배포 전 최종 확인:"
echo "1. terraform.tfvars의 모든 값이 올바른지 확인"
echo "2. Plan 결과를 검토하여 예상대로 리소스가 생성되는지 확인"
echo "3. 비용 예측 확인 (Dev: ~\$235/월, Prod: ~\$358/월)"
echo "4. 롤백 계획 수립"
echo ""
echo "배포 명령:"
echo -e "${GREEN}  cd envs/$ENV${NC}"
echo -e "${GREEN}  terraform apply ${ENV}.tfplan${NC}"
echo ""
