#!/bin/bash
# VPC 및 서브넷 구성 검증 스크립트

# 속성 2: VPC CIDR 블록
validate_vpc_cidr() {
  local vpc_cidr=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_vpc") | .values.cidr_block' plan.json)
  local expected_cidr="10.0.0.0/16"
  
  if [ "$vpc_cidr" == "$expected_cidr" ]; then
    echo "  VPC CIDR: $vpc_cidr"
    return 0
  else
    echo "  예상: $expected_cidr"
    echo "  실제: $vpc_cidr"
    return 1
  fi
}

# 속성 3: 서브넷 타입 구성
validate_subnet_types() {
  local public_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_subnet" and (.values.tags.Type == "public" or .address | contains("public")))] | length' plan.json)
  local private_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_subnet" and (.values.tags.Type == "private" or .address | contains("private")))] | length' plan.json)
  local data_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_subnet" and (.values.tags.Type == "data" or .address | contains("data")))] | length' plan.json)
  
  if [ "$ENV" == "dev" ]; then
    # Dev: 각 타입당 1개씩
    if [ "$public_count" -ge 1 ] && [ "$private_count" -ge 1 ] && [ "$data_count" -ge 1 ]; then
      echo "  Public: $public_count, Private: $private_count, Data: $data_count"
      return 0
    fi
  elif [ "$ENV" == "prod" ]; then
    # Prod: 각 타입당 2개씩 (Multi-AZ)
    if [ "$public_count" -ge 2 ] && [ "$private_count" -ge 2 ] && [ "$data_count" -ge 2 ]; then
      echo "  Public: $public_count, Private: $private_count, Data: $data_count"
      return 0
    fi
  fi
  
  echo "  Public: $public_count, Private: $private_count, Data: $data_count"
  return 1
}

# 속성 4: NAT Gateway 배치
validate_nat_gateway() {
  local nat_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_nat_gateway")] | length' plan.json)
  
  if [ "$ENV" == "dev" ]; then
    # Dev: 단일 NAT Gateway
    if [ "$nat_count" -eq 1 ]; then
      echo "  NAT Gateway 수: $nat_count (단일)"
      return 0
    fi
  elif [ "$ENV" == "prod" ]; then
    # Prod: Multi-AZ NAT Gateway
    if [ "$nat_count" -eq 2 ]; then
      echo "  NAT Gateway 수: $nat_count (Multi-AZ)"
      return 0
    fi
  fi
  
  echo "  예상: $([ "$ENV" == "dev" ] && echo "1" || echo "2")"
  echo "  실제: $nat_count"
  return 1
}

# 속성 5: VPC Endpoints 생성
validate_vpc_endpoints() {
  local endpoint_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_vpc_endpoint")] | length' plan.json)
  
  # ECR, S3, Secrets Manager용 VPC Endpoints (최소 3개)
  if [ "$endpoint_count" -ge 3 ]; then
    echo "  VPC Endpoints 수: $endpoint_count"
    return 0
  else
    echo "  예상: 최소 3개 (ECR, S3, Secrets Manager)"
    echo "  실제: $endpoint_count"
    return 1
  fi
}

validate_property 2 "VPC CIDR 블록" "validate_vpc_cidr"
validate_property 3 "서브넷 타입 구성" "validate_subnet_types"
validate_property 4 "NAT Gateway 배치" "validate_nat_gateway"
validate_property 5 "VPC Endpoints 생성" "validate_vpc_endpoints"
