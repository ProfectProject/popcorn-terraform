#!/bin/bash
# 보안 및 고가용성 검증 스크립트

# 속성 31: 데이터 암호화
validate_data_encryption() {
  local rds_encrypted=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_db_instance" and .name == "main") | .values.storage_encrypted' plan.json)
  local elasticache_encrypted=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.elasticache") | .resources[] | select(.type == "aws_elasticache_replication_group") | .values.transit_encryption_enabled' plan.json)
  
  if [ "$rds_encrypted" == "true" ] && [ "$elasticache_encrypted" == "true" ]; then
    echo "  RDS 암호화: $rds_encrypted, ElastiCache 암호화: $elasticache_encrypted"
    return 0
  else
    echo "  RDS 암호화: $rds_encrypted, ElastiCache 암호화: $elasticache_encrypted"
    return 1
  fi
}

# 속성 32: 보안 그룹 최소 권한
validate_security_group_least_privilege() {
  # 0.0.0.0/0 허용 규칙이 Public ALB에만 있는지 확인
  local public_open_rules=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group_rule" and .values.cidr_blocks and (.values.cidr_blocks | contains(["0.0.0.0/0"])) and (.address | contains("public_alb")))] | length' plan.json)
  local other_open_rules=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.security_groups") | .resources[] | select(.type == "aws_security_group_rule" and .values.cidr_blocks and (.values.cidr_blocks | contains(["0.0.0.0/0"])) and (.address | contains("public_alb") | not))] | length' plan.json)
  
  if [ "$public_open_rules" -ge 1 ] && [ "$other_open_rules" -eq 0 ]; then
    echo "  Public ALB만 0.0.0.0/0 허용 (최소 권한 원칙)"
    return 0
  else
    echo "  Public ALB 외 리소스에 0.0.0.0/0 허용 규칙 존재"
    return 1
  fi
}

# 속성 33: 환경별 고가용성 구성
validate_high_availability() {
  if [ "$ENV" == "prod" ]; then
    local rds_multi_az=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_db_instance" and .name == "main") | .values.multi_az' plan.json)
    local elasticache_failover=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.elasticache") | .resources[] | select(.type == "aws_elasticache_replication_group") | .values.automatic_failover_enabled' plan.json)
    local nat_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.vpc") | .resources[] | select(.type == "aws_nat_gateway")] | length' plan.json)
    
    if [ "$rds_multi_az" == "true" ] && [ "$elasticache_failover" == "true" ] && [ "$nat_count" -eq 2 ]; then
      echo "  RDS Multi-AZ: $rds_multi_az, ElastiCache 자동 장애조치: $elasticache_failover, NAT Gateway: $nat_count"
      return 0
    else
      echo "  RDS Multi-AZ: $rds_multi_az, ElastiCache 자동 장애조치: $elasticache_failover, NAT Gateway: $nat_count"
      return 1
    fi
  else
    # Dev 환경은 고가용성 불필요
    echo "  Dev 환경은 고가용성 구성 불필요"
    return 0
  fi
}

validate_property 31 "데이터 암호화" "validate_data_encryption"
validate_property 32 "보안 그룹 최소 권한" "validate_security_group_least_privilege"
validate_property 33 "환경별 고가용성 구성" "validate_high_availability"
