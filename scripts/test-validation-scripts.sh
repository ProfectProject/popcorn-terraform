#!/bin/bash
# 속성 검증 스크립트 구조 테스트

set -e

echo "=== 속성 검증 스크립트 구조 테스트 ==="

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# 스크립트 존재 여부 확인
check_script_exists() {
  local script_name=$1
  if [ -f "scripts/$script_name" ]; then
    echo -e "${GREEN}✓${NC} $script_name 존재"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $script_name 없음"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi
}

# 스크립트 실행 권한 확인
check_script_executable() {
  local script_name=$1
  if [ -x "scripts/$script_name" ]; then
    echo -e "${GREEN}✓${NC} $script_name 실행 권한 있음"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $script_name 실행 권한 없음"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi
}

# 스크립트 구문 검증
check_script_syntax() {
  local script_name=$1
  if bash -n "scripts/$script_name" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} $script_name 구문 올바름"
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $script_name 구문 오류"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    return 1
  fi
}

echo ""
echo "1. 메인 스크립트 검증"
check_script_exists "validate-properties.sh"
check_script_executable "validate-properties.sh"
check_script_syntax "validate-properties.sh"

echo ""
echo "2. AZ 구성 검증 스크립트"
check_script_exists "validate-az-config.sh"
check_script_executable "validate-az-config.sh"
check_script_syntax "validate-az-config.sh"

echo ""
echo "3. VPC 구성 검증 스크립트"
check_script_exists "validate-vpc-config.sh"
check_script_executable "validate-vpc-config.sh"
check_script_syntax "validate-vpc-config.sh"

echo ""
echo "4. EKS 구성 검증 스크립트"
check_script_exists "validate-eks-config.sh"
check_script_executable "validate-eks-config.sh"
check_script_syntax "validate-eks-config.sh"

echo ""
echo "5. RDS 구성 검증 스크립트"
check_script_exists "validate-rds-config.sh"
check_script_executable "validate-rds-config.sh"
check_script_syntax "validate-rds-config.sh"

echo ""
echo "6. ElastiCache 구성 검증 스크립트"
check_script_exists "validate-elasticache-config.sh"
check_script_executable "validate-elasticache-config.sh"
check_script_syntax "validate-elasticache-config.sh"

echo ""
echo "7. ALB 구성 검증 스크립트"
check_script_exists "validate-alb-config.sh"
check_script_executable "validate-alb-config.sh"
check_script_syntax "validate-alb-config.sh"

echo ""
echo "8. 보안 그룹 검증 스크립트"
check_script_exists "validate-security-groups.sh"
check_script_executable "validate-security-groups.sh"
check_script_syntax "validate-security-groups.sh"

echo ""
echo "9. IAM 역할 검증 스크립트"
check_script_exists "validate-iam-roles.sh"
check_script_executable "validate-iam-roles.sh"
check_script_syntax "validate-iam-roles.sh"

echo ""
echo "10. 모니터링 검증 스크립트"
check_script_exists "validate-monitoring.sh"
check_script_executable "validate-monitoring.sh"
check_script_syntax "validate-monitoring.sh"

echo ""
echo "11. 비용 최적화 검증 스크립트"
check_script_exists "validate-cost-optimization.sh"
check_script_executable "validate-cost-optimization.sh"
check_script_syntax "validate-cost-optimization.sh"

echo ""
echo "12. 보안 및 고가용성 검증 스크립트"
check_script_exists "validate-security-ha.sh"
check_script_executable "validate-security-ha.sh"
check_script_syntax "validate-security-ha.sh"

echo ""
echo "=== 테스트 결과 ==="
echo -e "${GREEN}통과: $PASS_COUNT${NC}"
echo -e "${RED}실패: $FAIL_COUNT${NC}"

if [ $FAIL_COUNT -eq 0 ]; then
  echo -e "\n${GREEN}모든 스크립트 구조 검증 통과!${NC}"
  exit 0
else
  echo -e "\n${RED}일부 스크립트 구조 검증 실패${NC}"
  exit 1
fi
