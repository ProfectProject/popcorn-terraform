#!/bin/bash
# EKS 구성 검증 스크립트

# 속성 6: EKS 클러스터 버전
validate_eks_version() {
  local eks_version=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_eks_cluster") | .values.version' plan.json)
  local expected_version="1.35"
  
  if [ "$eks_version" == "$expected_version" ]; then
    echo "  EKS 버전: $eks_version"
    return 0
  else
    echo "  예상: $expected_version"
    echo "  실제: $eks_version"
    return 1
  fi
}

# 속성 7: 환경별 EKS 노드 구성
validate_eks_node_config() {
  local instance_types=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_eks_node_group") | .values.instance_types | join(",")' plan.json)
  local desired_size=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_eks_node_group") | .values.scaling_config[0].desired_size' plan.json)
  local min_size=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_eks_node_group") | .values.scaling_config[0].min_size' plan.json)
  local max_size=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_eks_node_group") | .values.scaling_config[0].max_size' plan.json)
  
  if [ "$ENV" == "dev" ]; then
    # Dev: t3.medium, 2-5 노드
    if [[ "$instance_types" == *"t3.medium"* ]] && [ "$min_size" -eq 2 ] && [ "$max_size" -eq 5 ]; then
      echo "  인스턴스 타입: $instance_types"
      echo "  노드 수: $min_size-$max_size (희망: $desired_size)"
      return 0
    fi
  elif [ "$ENV" == "prod" ]; then
    # Prod: t3.medium~large, 3-5 노드
    if [[ "$instance_types" == *"t3.medium"* || "$instance_types" == *"t3.large"* ]] && [ "$min_size" -eq 3 ] && [ "$max_size" -eq 5 ]; then
      echo "  인스턴스 타입: $instance_types"
      echo "  노드 수: $min_size-$max_size (희망: $desired_size)"
      return 0
    fi
  fi
  
  echo "  인스턴스 타입: $instance_types"
  echo "  노드 수: $min_size-$max_size (희망: $desired_size)"
  return 1
}

validate_property 6 "EKS 클러스터 버전" "validate_eks_version"
validate_property 7 "환경별 EKS 노드 구성" "validate_eks_node_config"
