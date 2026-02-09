#!/bin/bash
# ALB 구성 검증 스크립트

# 속성 13: ALB 생성
validate_alb_creation() {
  local public_alb_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.public_alb") | .resources[] | select(.type == "aws_lb")] | length' plan.json)
  local management_alb_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.management_alb") | .resources[] | select(.type == "aws_lb")] | length' plan.json)
  
  if [ "$public_alb_count" -eq 1 ] && [ "$management_alb_count" -eq 1 ]; then
    echo "  Public ALB: $public_alb_count, Management ALB: $management_alb_count"
    return 0
  else
    echo "  Public ALB: $public_alb_count, Management ALB: $management_alb_count"
    return 1
  fi
}

# 속성 14: ALB HTTPS 리스너
validate_alb_https_listener() {
  local public_https_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.public_alb") | .resources[] | select(.type == "aws_lb_listener" and .values.port == 443)] | length' plan.json)
  local management_https_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.management_alb") | .resources[] | select(.type == "aws_lb_listener" and .values.port == 443)] | length' plan.json)
  
  if [ "$public_https_count" -ge 1 ] && [ "$management_https_count" -ge 1 ]; then
    echo "  Public ALB HTTPS: $public_https_count, Management ALB HTTPS: $management_https_count"
    return 0
  else
    echo "  Public ALB HTTPS: $public_https_count, Management ALB HTTPS: $management_https_count"
    return 1
  fi
}

# 속성 15: Public ALB 도메인 연결
validate_public_alb_domain() {
  local route53_count=$(jq '[.planned_values.root_module.resources[] | select(.type == "aws_route53_record" and (.values.name | contains("goormpopcorn.shop")))] | length' plan.json)
  
  if [ "$route53_count" -ge 1 ]; then
    echo "  Route53 레코드 수: $route53_count"
    return 0
  else
    echo "  Route53 레코드가 없습니다"
    return 1
  fi
}

# 속성 16: Management ALB 도메인 연결
validate_management_alb_domain() {
  local kafka_record=$(jq '[.planned_values.root_module.resources[] | select(.type == "aws_route53_record" and (.values.name | contains("kafka")))] | length' plan.json)
  local argocd_record=$(jq '[.planned_values.root_module.resources[] | select(.type == "aws_route53_record" and (.values.name | contains("argocd")))] | length' plan.json)
  local grafana_record=$(jq '[.planned_values.root_module.resources[] | select(.type == "aws_route53_record" and (.values.name | contains("grafana")))] | length' plan.json)
  
  if [ "$kafka_record" -ge 1 ] && [ "$argocd_record" -ge 1 ] && [ "$grafana_record" -ge 1 ]; then
    echo "  Kafka: $kafka_record, ArgoCD: $argocd_record, Grafana: $grafana_record"
    return 0
  else
    echo "  Kafka: $kafka_record, ArgoCD: $argocd_record, Grafana: $grafana_record"
    return 1
  fi
}

# 속성 17: Management ALB IP 화이트리스트
validate_management_alb_whitelist() {
  local sg_rules=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group_rule" and .values.security_group_id and (.address | contains("management_alb")))] | length' plan.json)
  
  if [ "$sg_rules" -ge 1 ]; then
    echo "  Management ALB 보안 그룹 규칙 수: $sg_rules"
    return 0
  else
    echo "  Management ALB 보안 그룹 규칙이 없습니다"
    return 1
  fi
}

validate_property 13 "ALB 생성" "validate_alb_creation"
validate_property 14 "ALB HTTPS 리스너" "validate_alb_https_listener"
validate_property 15 "Public ALB 도메인 연결" "validate_public_alb_domain"
validate_property 16 "Management ALB 도메인 연결" "validate_management_alb_domain"
validate_property 17 "Management ALB IP 화이트리스트" "validate_management_alb_whitelist"
