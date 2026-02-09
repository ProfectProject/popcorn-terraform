# RDS PostgreSQL vs Aurora PostgreSQL 비용 비교

## 개요

Popcorn MSA 프로젝트에서 모든 환경을 RDS PostgreSQL로 표준화하고, 프로덕션 환경은 Multi-AZ로 고가용성을 확보하되 동일한 최저 스펙(db.t4g.micro)을 사용하여 비용을 최적화합니다.

## 비용 비교 (월 기준, ap-northeast-2)

### Dev 환경

| 구성 요소 | RDS PostgreSQL | Aurora PostgreSQL | 절감액 |
|-----------|----------------|-------------------|--------|
| **인스턴스** | db.t4g.micro (단일 AZ) | Aurora Serverless v2 (0.5 ACU) | |
| 컴퓨팅 비용 | $13.14 | $43.20 | **$30.06** |
| 스토리지 (20GB) | $2.30 | $2.30 | $0 |
| 백업 (20GB, 1일) | $2.30 | $2.30 | $0 |
| I/O 비용 | 포함 | $0.20/백만 요청 | 변동 |
| **월 총 비용** | **$17.74** | **$47.80** | **$30.06 (63% 절감)** |

### Prod 환경

| 구성 요소 | RDS PostgreSQL | Aurora PostgreSQL | 절감액 |
|-----------|----------------|-------------------|--------|
| **인스턴스** | db.t4g.micro (Multi-AZ) | db.r6g.large (Multi-AZ) | |
| 컴퓨팅 비용 | $26.28 | $438.00 | **$411.72** |
| 스토리지 (50GB) | $5.75 | $5.75 | $0 |
| 백업 (350GB, 7일) | $16.10 | $16.10 | $0 |
| I/O 비용 | 포함 | $0.20/백만 요청 | 변동 |
| **월 총 비용** | **$48.13** | **$459.85** | **$411.72 (90% 절감)** |

## 총 절감 효과

| 환경 | RDS PostgreSQL | Aurora PostgreSQL | 월 절감액 | 연 절감액 |
|------|----------------|-------------------|-----------|-----------|
| Dev | $17.74 | $47.80 | $30.06 | $360.72 |
| Prod | $48.13 | $459.85 | $411.72 | $4,940.64 |
| **합계** | **$65.87** | **$507.65** | **$441.78** | **$5,301.36** |

## 기술적 비교

### RDS PostgreSQL 장점

| 특징 | RDS PostgreSQL | Aurora PostgreSQL |
|------|----------------|-------------------|
| **비용 효율성** | ✅ 매우 높음 | ❌ 높은 비용 |
| **운영 단순성** | ✅ 표준 PostgreSQL | ⚠️ Aurora 특화 기능 |
| **예측 가능한 비용** | ✅ 고정 비용 | ❌ 변동 비용 (I/O) |
| **최소 스펙 지원** | ✅ db.t4g.micro | ❌ 최소 0.5 ACU |
| **Multi-AZ 지원** | ✅ 지원 | ✅ 지원 |
| **자동 백업** | ✅ 지원 | ✅ 지원 |
| **Read Replica** | ✅ 최대 5개 | ✅ 최대 15개 |
| **성능** | ⚠️ 표준 | ✅ 고성능 |
| **자동 스케일링** | ❌ 수동 | ✅ 자동 |

### 성능 비교

| 메트릭 | db.t4g.micro (RDS) | 0.5 ACU (Aurora) | db.r6g.large (Aurora) |
|--------|-------------------|------------------|----------------------|
| **vCPU** | 2 | 1 | 2 |
| **메모리** | 1 GB | 1 GB | 16 GB |
| **네트워크** | 최대 5 Gbps | 최대 5 Gbps | 최대 10 Gbps |
| **IOPS** | 3,000 | 3,000 | 13,600 |
| **연결 수** | ~100 | ~100 | ~1,600 |

## 비즈니스 요구사항 적합성

### Popcorn MSA 트래픽 패턴

```yaml
평상시: 10-50 TPS
팝업 오픈: 1,000-10,000 TPS (100-1000배 급증)
피크 지속: 5-30분
예측 가능: 사전 공지
```

### RDS PostgreSQL 적합성 분석

| 요구사항 | RDS PostgreSQL 대응 | 평가 |
|----------|-------------------|------|
| **비용 효율성** | 월 $65.87 vs Aurora $507.65 | ✅ 매우 우수 |
| **트래픽 급증 대응** | Read Replica + Connection Pooling | ✅ 충분 |
| **가용성 (99.9%)** | Multi-AZ 자동 장애조치 | ✅ 충족 |
| **백업/복구** | 자동 백업, PITR | ✅ 충족 |
| **운영 단순성** | 표준 PostgreSQL | ✅ 우수 |
| **확장성** | 수동 스케일링 | ⚠️ 제한적 |

## 확장 전략

### 단계별 확장 계획

**1단계 (초기 3개월)**
- RDS PostgreSQL db.t4g.micro Multi-AZ
- 비용: $48.13/월
- 대응 가능: ~1,000 TPS

**2단계 (3-6개월)**
- Read Replica 1개 추가
- 비용: $74.41/월 (+$26.28)
- 대응 가능: ~3,000 TPS

**3단계 (6-12개월)**
- 인스턴스 업그레이드: db.t4g.small
- Read Replica 2개
- 비용: $157.68/월
- 대응 가능: ~10,000 TPS

**4단계 (12개월 이후)**
- Aurora PostgreSQL 전환 고려
- 완전 자동 스케일링 필요 시

## 모니터링 및 알림

### RDS PostgreSQL 모니터링

```yaml
기본 메트릭:
  - CPU 사용률: < 70%
  - 연결 수: < 80% of max_connections
  - 스토리지 여유 공간: > 2GB
  - 읽기/쓰기 지연시간: < 200ms

Enhanced Monitoring (Prod):
  - 1분 간격 상세 메트릭
  - OS 레벨 모니터링

Performance Insights (Prod):
  - 쿼리 성능 분석
  - 대기 이벤트 모니터링
```

### 알림 설정

```yaml
Dev 환경:
  - 알림 없음 (비용 절약)
  - CloudWatch 메트릭만 수집

Prod 환경:
  - SNS 토픽 연동
  - Slack 알림
  - 임계값 초과 시 즉시 알림
```

## 마이그레이션 가이드

### Aurora에서 RDS PostgreSQL 마이그레이션

```bash
# 1. Aurora 스냅샷 생성
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier popcorn-aurora \
  --db-cluster-snapshot-identifier popcorn-migration-snapshot

# 2. RDS PostgreSQL로 복원
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier popcorn-postgres \
  --db-snapshot-identifier popcorn-migration-snapshot \
  --db-instance-class db.t4g.micro \
  --multi-az

# 3. 애플리케이션 연결 문자열 업데이트
# Aurora: cluster-endpoint
# RDS: instance-endpoint
```

### 다운타임 최소화 전략

```yaml
1. Blue/Green 배포:
   - 새 RDS 인스턴스 생성
   - 데이터 동기화 (DMS 사용)
   - DNS 전환

2. Read Replica 활용:
   - Aurora Read Replica 생성
   - RDS로 승격
   - 애플리케이션 전환

3. 백업/복원:
   - 스냅샷 기반 마이그레이션
   - 다운타임: 10-30분
```

## 결론

### 권장사항

1. **모든 환경 RDS PostgreSQL 사용**
   - 비용 효율성: 연간 $5,301 절감
   - 운영 단순성: 표준 PostgreSQL
   - 일관된 환경: Dev/Prod 동일 엔진

2. **환경별 차별화**
   - Dev: 단일 AZ, 최소 백업, 모니터링 최소화
   - Prod: Multi-AZ, 강화된 백업, 상세 모니터링

3. **점진적 확장**
   - 초기: db.t4g.micro로 시작
   - 필요 시: Read Replica 추가
   - 장기: Aurora 전환 고려

4. **모니터링 강화**
   - Performance Insights 활용
   - 쿼리 성능 최적화
   - 사전 예방적 알림

### 비즈니스 임팩트

- **비용 절감**: 연간 $5,301 (87% 절감)
- **운영 효율성**: 표준 PostgreSQL로 학습 곡선 최소화
- **확장성**: 필요에 따른 점진적 확장 가능
- **안정성**: Multi-AZ로 99.9% 가용성 확보

이 구성으로 초기 스타트업 예산 내에서 안정적이고 확장 가능한 데이터베이스 인프라를 구축할 수 있습니다.