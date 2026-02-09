#!/bin/bash
# 환경별 AZ 구성 검증 스크립트

# 속성 1: 환경별 AZ 구성
# Dev 환경은 단일 AZ(ap-northeast-2a), Prod 환경은 Multi-AZ(ap-northeast-2a, ap-northeast-2c)
validate_az_config() {
  local az_list=$(jq -r '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_subnet") | .values.availability_zone] | unique | sort | join(",")' plan.json)
  
  if [ "$ENV" == "dev" ]; then
    # Dev 환경: 단일 AZ 검증
    local expected_azs="ap-northeast-2a"
    if [ "$az_list" == "$expected_azs" ]; then
      echo "  Dev 환경 AZ 구성: $az_list"
      return 0
    else
      echo "  예상: $expected_azs"
      echo "  실제: $az_list"
      return 1
    fi
  elif [ "$ENV" == "prod" ]; then
    # Prod 환경: Multi-AZ 검증
    local expected_azs="ap-northeast-2a,ap-northeast-2c"
    if [ "$az_list" == "$expected_azs" ]; then
      echo "  Prod 환경 AZ 구성: $az_list"
      return 0
    else
      echo "  예상: $expected_azs"
      echo "  실제: $az_list"
      return 1
    fi
  fi
}

validate_property 1 "환경별 AZ 구성" "validate_az_config"
