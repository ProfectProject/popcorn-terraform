#!/bin/bash
# ElastiCache 구성 검증 스크립트

# 속성 11: 환경별 ElastiCache 구성
validate_elasticache_config() {
  local node_type=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.elasticache") | .resources[] | select(.type == "aws_elasticache_replication_group") | .values.node_type' plan.json)
  local num_cache_clusters=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.elasticache") | .resources[] | select(.type == "aws_elasticache_replication_group") | .values.num_cache_clusters' plan.json)
  local automatic_failover=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.elasticache") | .resources[] | select(.type == "aws_elasticache_replication_group") | .values.automatic_failover_enabled' plan.json)
  
  if [ "$ENV" == "dev" ]; then
    # Dev: cache.t4g.micro, 단일 노드
    if [ "$node_type" == "cache.t4g.micro" ] && [ "$num_cache_clusters" -eq 1 ]; then
      echo "  노드 타입: $node_type, 노드 수: $num_cache_clusters"
      return 0
    fi
  elif [ "$ENV" == "prod" ]; then
    # Prod: cache.t4g.small, Primary + Replica, 자동 장애조치
    if [ "$node_type" == "cache.t4g.small" ] && [ "$num_cache_clusters" -eq 2 ] && [ "$automatic_failover" == "true" ]; then
      echo "  노드 타입: $node_type, 노드 수: $num_cache_clusters, 자동 장애조치: $automatic_failover"
      return 0
    fi
  fi
  
  echo "  노드 타입: $node_type, 노드 수: $num_cache_clusters, 자동 장애조치: $automatic_failover"
  return 1
}

# 속성 12: ElastiCache 암호화
validate_elasticache_encryption() {
  local transit_encryption=$(jq -r '.planned_values.root_module.child_modules[] | select(.address == "module.elasticache") | .resources[] | select(.type == "aws_elasticache_replication_group") | .values.transit_encryption_enabled' plan.json)
  
  if [ "$transit_encryption" == "true" ]; then
    echo "  전송 중 암호화: 활성화"
    return 0
  else
    echo "  전송 중 암호화: 비활성화"
    return 1
  fi
}

validate_property 11 "환경별 ElastiCache 구성" "validate_elasticache_config"
validate_property 12 "ElastiCache 암호화" "validate_elasticache_encryption"
