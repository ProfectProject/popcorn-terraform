# ElastiCache Valkey 마이그레이션 가이드

## 📋 변경 사항 요약

### 엔진 변경
- **이전**: Redis 7.0
- **이후**: Valkey 8.0

### 환경별 설정

#### Dev 환경 (최소 비용 최적화)
```hcl
# 노드 설정
node_type           = "cache.t4g.micro"    # 1 vCPU, 0.5GB RAM
engine_version      = "8.0"               # Valkey 8.0
num_cache_clusters  = 1                   # 단일 노드

# 고가용성 설정
automatic_failover  = false               # 비활성화
multi_az_enabled    = false               # 비활성화

# 보안 설정
at_rest_encryption_enabled    = true      # 저장 시 암호화
transit_encryption_enabled    = false     # 전송 암호화 비활성화 (성능 우선)

# 백업 및 유지보수
apply_immediately        = true           # 즉시 적용
snapshot_retention_limit = 1              # 1일 백업 보존
snapshot_window         = "03:00-05:00"   # 새벽 백업
maintenance_window      = "sun:05:00-sun:07:00"  # 일요일 새벽 유지보수
```

#### Prod 환경 (고가용성 및 보안 최적화)
```hcl
# 노드 설정
node_type           = "cache.t4g.small"   # 2 vCPU, 1.37GB RAM (비용 효율적)
engine_version      = "8.0"              # Valkey 8.0
num_cache_clusters  = 2                  # Primary + Replica

# 고가용성 설정
automatic_failover  = true               # 자동 장애조치
multi_az_enabled    = true               # Multi-AZ 배포

# 보안 설정
at_rest_encryption_enabled    = true     # 저장 시 암호화
transit_encryption_enabled    = true     # 전송 시 암호화 (보안 우선)

# 백업 및 유지보수
apply_immediately        = false         # 유지보수 창에서 적용
snapshot_retention_limit = 7             # 7일 백업 보존
snapshot_window         = "02:00-04:00"  # 새벽 백업
maintenance_window      = "sun:04:00-sun:06:00"  # 일요일 새벽 유지보수
```

## 🔄 마이그레이션 절차

### 1. 사전 준비
```bash
# 현재 Redis 데이터 백업 확인
aws elasticache describe-snapshots \
  --replication-group-id goorm-popcorn-cache-dev

# 애플리케이션 연결 확인
aws elasticache describe-replication-groups \
  --replication-group-id goorm-popcorn-cache-dev
```

### 2. Dev 환경 마이그레이션
```bash
cd popcorn-terraform-feature/envs/dev

# Terraform 계획 확인
terraform plan

# 마이그레이션 실행 (다운타임 발생)
terraform apply
```

### 3. Prod 환경 마이그레이션
```bash
cd popcorn-terraform-feature/envs/prod

# 유지보수 창 확인 및 계획
terraform plan

# 프로덕션 마이그레이션 (유지보수 창에서 실행)
terraform apply
```

## 📊 성능 및 비용 비교

### Dev 환경
| 구분 | Redis 7.0 | Valkey 8.0 | 개선사항 |
|------|-----------|------------|----------|
| 엔진 | Redis | Valkey | 오픈소스, 성능 개선 |
| 노드 | cache.t4g.micro | cache.t4g.micro | 동일 |
| 비용 | ~$12/월 | ~$12/월 | 동일 |
| 성능 | 기본 | 향상 | 최대 2배 RPS 개선 |

### Prod 환경
| 구분 | Redis 7.0 | Valkey 8.0 | 개선사항 |
|------|-----------|------------|----------|
| 엔진 | Redis | Valkey | 오픈소스, 성능 개선 |
| 노드 | cache.t4g.small | cache.t4g.small | 동일 |
| 구성 | 단일 노드 | Primary + Replica | 고가용성 확보 |
| 비용 | ~$23/월 | ~$47/월 | 2배 (고가용성 확보) |
| 메모리 | 1.37GB | 1.37GB | 동일 |
| 성능 | 기본 | 향상 | Valkey 최적화 |

## 🚀 Valkey 8.0 주요 개선사항

### 성능 향상
- **RPS 개선**: 기존 대비 최대 2배 요청 처리 성능
- **메모리 효율성**: 향상된 메모리 관리
- **네트워크 최적화**: 더 빠른 데이터 전송

### 새로운 기능
- **향상된 데이터 구조**: 새로운 데이터 타입 지원
- **개선된 복제**: 더 안정적인 Primary-Replica 동기화
- **모니터링**: 향상된 메트릭 및 로깅

### 호환성
- **Redis 호환**: 기존 Redis 명령어 100% 호환
- **클라이언트 라이브러리**: 기존 Redis 클라이언트 그대로 사용 가능
- **애플리케이션**: 코드 변경 없이 마이그레이션 가능

## ⚠️ 주의사항

### 마이그레이션 시 다운타임
- **Dev 환경**: 약 5-10분 다운타임 예상
- **Prod 환경**: 유지보수 창에서 실행 권장

### 애플리케이션 호환성
- Redis 클라이언트 라이브러리 그대로 사용 가능
- 연결 문자열 변경 불필요
- 기존 Redis 명령어 모두 지원

### 모니터링
```bash
# CloudWatch 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CPUUtilization \
  --dimensions Name=CacheClusterId,Value=goorm-popcorn-cache-dev-001 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average
```

## 🔧 롤백 계획

만약 문제가 발생할 경우:

1. **즉시 롤백** (Dev 환경)
```bash
# 이전 스냅샷에서 Redis 클러스터 복원
aws elasticache create-replication-group \
  --replication-group-id goorm-popcorn-cache-dev-rollback \
  --snapshot-name goorm-popcorn-cache-dev-backup
```

2. **계획된 롤백** (Prod 환경)
```bash
# 유지보수 창에서 이전 설정으로 복원
terraform apply -var="elasticache_engine_version=7.0"
```

## 📈 마이그레이션 후 검증

### 성능 테스트
```bash
# Redis 벤치마크 도구 사용
redis-benchmark -h <valkey-endpoint> -p 6379 -n 100000 -c 50
```

### 연결 테스트
```bash
# 애플리케이션에서 연결 확인
redis-cli -h <valkey-endpoint> -p 6379 ping
```

### 모니터링 대시보드
- CloudWatch에서 CPU, 메모리, 네트워크 사용률 확인
- 애플리케이션 로그에서 캐시 히트율 모니터링
- 응답 시간 및 처리량 메트릭 추적

---

**마이그레이션 완료 후 이 문서를 업데이트하여 실제 결과를 기록하세요.**