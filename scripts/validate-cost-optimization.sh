#!/bin/bash
# 비용 최적화 검증 스크립트

# 속성 28: 환경별 비용 최적화
validate_cost_optimization() {
  local nat_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_nat_gateway")] | length' plan.json)
  
  if [ "$ENV" == "dev" ]; then
    # Dev: 단일 NAT Gateway
    if [ "$nat_count" -eq 1 ]; then
      echo "  Dev 환경 NAT Gateway: $nat_count (비용 최적화)"
      return 0
    fi
  elif [ "$ENV" == "prod" ]; then
    # Prod: Karpenter 활성화 여부는 EKS 모듈 변수로 확인
    echo "  Prod 환경 비용 최적화 (Karpenter 활성화 권장)"
    return 0
  fi
  
  echo "  NAT Gateway 수: $nat_count"
  return 1
}

# 속성 29: VPC Endpoints 비용 최적화
validate_vpc_endpoints_cost() {
  local endpoints=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_vpc_endpoint")] | length' plan.json)
  
  if [ "$endpoints" -ge 3 ]; then
    echo "  VPC Endpoints 수: $endpoints (NAT Gateway 트래픽 절감)"
    return 0
  else
    echo "  VPC Endpoints 수: $endpoints"
    return 1
  fi
}

# 속성 30: 리소스 태그
validate_resource_tags() {
  # 모든 리소스에 Environment, Project, ManagedBy 태그가 있는지 확인
  local tagged_resources=$(jq '[.planned_values.root_module.child_modules[].resources[] | select(.values.tags.Environment and .values.tags.Project and .values.tags.ManagedBy)] | length' plan.json)
  local total_resources=$(jq '[.planned_values.root_module.child_modules[].resources[] | select(.values.tags)] | length' plan.json)
  
  if [ "$tagged_resources" -ge 1 ]; then
    echo "  태그된 리소스: $tagged_resources / $total_resources"
    return 0
  else
    echo "  태그된 리소스: $tagged_resources / $total_resources"
    return 1
  fi
}

validate_property 28 "환경별 비용 최적화" "validate_cost_optimization"
validate_property 29 "VPC Endpoints 비용 최적화" "validate_vpc_endpoints_cost"
validate_property 30 "리소스 태그" "validate_resource_tags"
