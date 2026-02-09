#!/bin/bash
# 모니터링 검증 스크립트

# 속성 25: CloudWatch 로그 수집
validate_cloudwatch_logs() {
  local log_groups=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.eks") | .resources[] | select(.type == "aws_cloudwatch_log_group")] | length' plan.json)
  
  if [ "$log_groups" -ge 1 ]; then
    echo "  CloudWatch Log Groups 수: $log_groups"
    return 0
  else
    echo "  CloudWatch Log Groups가 없습니다"
    return 1
  fi
}

# 속성 26: CloudWatch 메트릭 수집
validate_cloudwatch_metrics() {
  # RDS, ElastiCache, ALB는 기본적으로 CloudWatch 메트릭을 전송
  # 리소스 존재 여부로 검증
  local rds_exists=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.rds") | .resources[] | select(.type == "aws_db_instance")] | length' plan.json)
  local elasticache_exists=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.elasticache") | .resources[] | select(.type == "aws_elasticache_replication_group")] | length' plan.json)
  local alb_exists=$(jq '[.planned_values.root_module.child_modules[] | select(.address | contains("alb")) | .resources[] | select(.type == "aws_lb")] | length' plan.json)
  
  if [ "$rds_exists" -ge 1 ] && [ "$elasticache_exists" -ge 1 ] && [ "$alb_exists" -ge 1 ]; then
    echo "  RDS, ElastiCache, ALB 메트릭 수집 활성화"
    return 0
  else
    echo "  일부 리소스의 메트릭 수집이 비활성화되어 있습니다"
    return 1
  fi
}

# 속성 27: CloudWatch 알람
validate_cloudwatch_alarms() {
  local alarms=$(jq '[.planned_values.root_module.child_modules[] | select(.address == "module.monitoring" or .address == "module.rds" or .address | contains("alb")) | .resources[] | select(.type == "aws_cloudwatch_metric_alarm")] | length' plan.json)
  
  if [ "$alarms" -ge 1 ]; then
    echo "  CloudWatch Alarms 수: $alarms"
    return 0
  else
    echo "  CloudWatch Alarms가 없습니다"
    return 1
  fi
}

validate_property 25 "CloudWatch 로그 수집" "validate_cloudwatch_logs"
validate_property 26 "CloudWatch 메트릭 수집" "validate_cloudwatch_metrics"
validate_property 27 "CloudWatch 알람" "validate_cloudwatch_alarms"
