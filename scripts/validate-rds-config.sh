#!/bin/bash
# RDS 구성 검증 스크립트

# 속성 8: 환경별 RDS 구성
validate_rds_config() {
  local instance_class=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_db_instance" and .name == "main") | .values.instance_class' plan.json)
  local multi_az=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_db_instance" and .name == "main") | .values.multi_az' plan.json)
  local backup_retention=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_db_instance" and .name == "main") | .values.backup_retention_period' plan.json)
  
  if [ "$ENV" == "dev" ]; then
    # Dev: db.t4g.micro, 단일 AZ, 1일 백업
    if [ "$instance_class" == "db.t4g.micro" ] && [ "$multi_az" == "false" ] && [ "$backup_retention" -eq 1 ]; then
      echo "  인스턴스: $instance_class, Multi-AZ: $multi_az, 백업: ${backup_retention}일"
      return 0
    fi
  elif [ "$ENV" == "prod" ]; then
    # Prod: db.t4g.micro, Multi-AZ, 7일 백업
    if [ "$instance_class" == "db.t4g.micro" ] && [ "$multi_az" == "true" ] && [ "$backup_retention" -eq 7 ]; then
      echo "  인스턴스: $instance_class, Multi-AZ: $multi_az, 백업: ${backup_retention}일"
      return 0
    fi
  fi
  
  echo "  인스턴스: $instance_class, Multi-AZ: $multi_az, 백업: ${backup_retention}일"
  return 1
}

# 속성 9: RDS 암호화
validate_rds_encryption() {
  local storage_encrypted=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_db_instance" and .name == "main") | .values.storage_encrypted' plan.json)
  
  if [ "$storage_encrypted" == "true" ]; then
    echo "  저장 시 암호화: 활성화"
    return 0
  else
    echo "  저장 시 암호화: 비활성화"
    return 1
  fi
}

# 속성 10: RDS 자격증명 관리
validate_rds_secrets() {
  local secrets_count=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_secretsmanager_secret")] | length' plan.json)
  
  if [ "$secrets_count" -ge 1 ]; then
    echo "  Secrets Manager 시크릿 수: $secrets_count"
    return 0
  else
    echo "  Secrets Manager 시크릿이 없습니다"
    return 1
  fi
}

validate_property 8 "환경별 RDS 구성" "validate_rds_config"
validate_property 9 "RDS 암호화" "validate_rds_encryption"
validate_property 10 "RDS 자격증명 관리" "validate_rds_secrets"
