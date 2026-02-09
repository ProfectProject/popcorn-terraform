#!/bin/bash
# Terraform 인프라 속성 검증 스크립트
# 설계 문서의 정확성 속성을 Terraform plan 출력으로 검증합니다

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 환경 변수 확인
if [ -z "$ENV" ]; then
  echo -e "${RED}ERROR: ENV 환경 변수가 설정되지 않았습니다 (dev 또는 prod)${NC}"
  exit 1
fi

if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
  echo -e "${RED}ERROR: ENV는 'dev' 또는 'prod'여야 합니다${NC}"
  exit 1
fi

echo -e "${YELLOW}=== Terraform 속성 검증 시작 (환경: $ENV) ===${NC}"

# Terraform plan 실행 및 JSON 출력
echo -e "${YELLOW}Terraform plan 실행 중...${NC}"
cd "envs/$ENV"
terraform plan -out=plan.tfplan > /dev/null 2>&1
terraform show -json plan.tfplan > plan.json

# 검증 결과 카운터
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

# 검증 함수
validate_property() {
  local property_num=$1
  local property_name=$2
  local validation_command=$3
  
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo -e "\n${YELLOW}속성 $property_num: $property_name${NC}"
  
  if eval "$validation_command"; then
    echo -e "${GREEN}✓ PASS${NC}"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  else
    echo -e "${RED}✗ FAIL${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi
}

# 검증 스크립트 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 각 속성 검증 스크립트 실행
source "$SCRIPT_DIR/validate-az-config.sh"
source "$SCRIPT_DIR/validate-vpc-config.sh"
source "$SCRIPT_DIR/validate-eks-config.sh"
source "$SCRIPT_DIR/validate-rds-config.sh"
source "$SCRIPT_DIR/validate-elasticache-config.sh"
source "$SCRIPT_DIR/validate-alb-config.sh"
source "$SCRIPT_DIR/validate-security-groups.sh"
source "$SCRIPT_DIR/validate-iam-roles.sh"
source "$SCRIPT_DIR/validate-monitoring.sh"
source "$SCRIPT_DIR/validate-cost-optimization.sh"
source "$SCRIPT_DIR/validate-security-ha.sh"

# 결과 출력
echo -e "\n${YELLOW}=== 검증 결과 ===${NC}"
echo -e "총 속성: $TOTAL_COUNT"
echo -e "${GREEN}통과: $PASS_COUNT${NC}"
echo -e "${RED}실패: $FAIL_COUNT${NC}"

# 정리
rm -f plan.tfplan plan.json

# 종료 코드
if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "\n${GREEN}모든 속성 검증 통과!${NC}"
  exit 0
else
  echo -e "\n${RED}일부 속성 검증 실패${NC}"
  exit 1
fi
