#!/bin/bash
# 보안 그룹 검증 스크립트

# 속성 18: 보안 그룹 생성
validate_security_groups_creation() {
  local sg_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group")] | length' plan.json)
  
  # Public ALB, Management ALB, EKS Node, RDS, ElastiCache (최소 5개)
  if [ "$sg_count" -ge 5 ]; then
    echo "  보안 그룹 수: $sg_count"
    return 0
  else
    echo "  예상: 최소 5개"
    echo "  실제: $sg_count"
    return 1
  fi
}

# 속성 19: Public ALB 보안 그룹 규칙
validate_public_alb_sg_rules() {
  local http_rule=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group_rule" and .values.from_port == 80 and (.address | contains("public_alb")))] | length' plan.json)
  local https_rule=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group_rule" and .values.from_port == 443 and (.address | contains("public_alb")))] | length' plan.json)
  
  if [ "$http_rule" -ge 1 ] && [ "$https_rule" -ge 1 ]; then
    echo "  HTTP 규칙: $http_rule, HTTPS 규칙: $https_rule"
    return 0
  else
    echo "  HTTP 규칙: $http_rule, HTTPS 규칙: $https_rule"
    return 1
  fi
}

# 속성 20: EKS Node 보안 그룹 규칙
validate_eks_node_sg_rules() {
  local sg_rules=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_security_group_rule" and (.address | contains("node_group")))] | length' plan.json)
  
  if [ "$sg_rules" -ge 1 ]; then
    echo "  EKS Node 보안 그룹 규칙 수: $sg_rules"
    return 0
  else
    echo "  EKS Node 보안 그룹 규칙이 없습니다"
    return 1
  fi
}

# 속성 21: RDS 보안 그룹 규칙
validate_rds_sg_rules() {
  local sg_rules=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group_rule" and .values.from_port == 5432 and (.address | contains("rds")))] | length' plan.json)
  
  if [ "$sg_rules" -ge 1 ]; then
    echo "  RDS 보안 그룹 규칙 수: $sg_rules"
    return 0
  else
    echo "  RDS 보안 그룹 규칙이 없습니다"
    return 1
  fi
}

# 속성 22: ElastiCache 보안 그룹 규칙
validate_elasticache_sg_rules() {
  local sg_rules=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group_rule" and .values.from_port == 6379 and (.address | contains("elasticache")))] | length' plan.json)
  
  if [ "$sg_rules" -ge 1 ]; then
    echo "  ElastiCache 보안 그룹 규칙 수: $sg_rules"
    return 0
  else
    echo "  ElastiCache 보안 그룹 규칙이 없습니다"
    return 1
  fi
}

validate_property 18 "보안 그룹 생성" "validate_security_groups_creation"
validate_property 19 "Public ALB 보안 그룹 규칙" "validate_public_alb_sg_rules"
validate_property 20 "EKS Node 보안 그룹 규칙" "validate_eks_node_sg_rules"
validate_property 21 "RDS 보안 그룹 규칙" "validate_rds_sg_rules"
validate_property 22 "ElastiCache 보안 그룹 규칙" "validate_elasticache_sg_rules"
