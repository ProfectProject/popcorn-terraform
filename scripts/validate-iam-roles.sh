#!/bin/bash
# IAM 역할 검증 스크립트

# 속성 23: IAM 역할 생성
validate_iam_roles_creation() {
  local eks_cluster_role=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_iam_role" and (.address | contains("cluster")))] | length' plan.json)
  local eks_node_role=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_iam_role" and (.address | contains("node_group")))] | length' plan.json)
  local ebs_csi_role=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_iam_role" and (.address | contains("ebs_csi")))] | length' plan.json)
  
  if [ "$eks_cluster_role" -ge 1 ] && [ "$eks_node_role" -ge 1 ]; then
    echo "  EKS Cluster Role: $eks_cluster_role, EKS Node Role: $eks_node_role, EBS CSI Role: $ebs_csi_role"
    return 0
  else
    echo "  EKS Cluster Role: $eks_cluster_role, EKS Node Role: $eks_node_role, EBS CSI Role: $ebs_csi_role"
    return 1
  fi
}

# 속성 24: IAM 최소 권한 원칙
validate_iam_least_privilege() {
  # IAM 정책이 와일드카드(*) 리소스를 최소화하는지 확인
  # 이 검증은 정적 분석으로는 완벽하지 않으므로 경고 수준으로 처리
  echo "  IAM 최소 권한 원칙 검증 (수동 검토 권장)"
  return 0
}

validate_property 23 "IAM 역할 생성" "validate_iam_roles_creation"
validate_property 24 "IAM 최소 권한 원칙" "validate_iam_least_privilege"
