# Popcorn MSA 모니터링 설정 문서

## 개요

본 문서는 Popcorn MSA Dev 환경의 모니터링 시스템 구성과 주요 관찰 지표를 상세히 기술합니다.

## 모니터링 아키텍처

### 핵심 구성 요소
- **CloudWatch Dashboard**: 통합 모니터링 대시보드
- **CloudWatch Metrics**: 시스템 성능 지표 수집
- **CloudWatch Logs**: 애플리케이션 및 시스템 로그
- **CloudWatch Alarms**: 임계값 기반 알림 시스템
- **Container Insights**: ECS 컨테이너 상세 모니터링

## CloudWatch Dashboard

### 대시보드 정보
- **이름**: `goorm-popcorn-dev-overview`
- **위치**: AWS Console > CloudWatch > Dashboards
- **업데이트 주기**: 5분 (300초)

### 대시보드 구성 (5개 위젯)

#### 1. ALB Metrics (좌상단)
```yaml
위치: (0,0) - 12x6
메트릭:
  - RequestCount: 총 요청 수
  - TargetResponseTime: 평균 응답 시간
  - HTTPCode_Target_2XX_Count: 성공 응답 수
  - HTTPCode_Target_4XX_Count: 클라이언트 오류 수
  - HTTPCode_Target_5XX_Count: 서버 오류 수
```

#### 2. ECS Service Metrics (우상단)
```yaml
위치: (12,0) - 12x6
모니터링 서비스:
  - api-gateway: CPU/Memory 사용률
  - user-service: CPU/Memory 사용률
  - payment-front: CPU/Memory 사용률
메트릭:
  - CPUUtilization: CPU 사용률 (%)
  - MemoryUtilization: 메모리 사용률 (%)
```

#### 3. RDS Metrics (좌하단)
```yaml
위치: (0,6) - 12x6
메트릭:
  - CPUUtilization: CPU 사용률
  - DatabaseConnections: 활성 연결 수
  - FreeableMemory: 사용 가능한 메모리
  - ReadLatency: 읽기 지연 시간
  - WriteLatency: 쓰기 지연 시간
```

#### 4. ElastiCache Metrics (우하단)
```yaml
위치: (12,6) - 12x6
메트릭:
  - CPUUtilization: CPU 사용률
  - FreeableMemory: 사용 가능한 메모리
  - CurrConnections: 현재 연결 수
  - CacheHitRate: 캐시 히트율
```

#### 5. Recent Application Errors (하단 전체)
```yaml
위치: (0,12) - 24x6
타입: 로그 쿼리
소스: /aws/ecs/goorm-popcorn-dev/api-gateway
쿼리: ERROR 레벨 로그 최근 20개
정렬: 시간 역순
```

## CloudWatch Alarms

### ALB 관련 알람

#### 1. 높은 응답 시간 알람
```yaml
이름: goorm-popcorn-alb-dev-alb-high-response-time
메트릭: TargetResponseTime
임계값: 1.0초
평가 기간: 2회 연속
주기: 5분
비교 연산자: GreaterThanThreshold
```

#### 2. 4xx 에러율 알람
```yaml
이름: goorm-popcorn-alb-dev-alb-high-4xx-errors
메트릭: HTTPCode_Target_4XX_Count
임계값: 10개
평가 기간: 2회 연속
주기: 5분
비교 연산자: GreaterThanThreshold
```

#### 3. 5xx 에러율 알람
```yaml
이름: goorm-popcorn-alb-dev-alb-high-5xx-errors
메트릭: HTTPCode_Target_5XX_Count
임계값: 5개
평가 기간: 1회
주기: 5분
비교 연산자: GreaterThanThreshold
```

### ElastiCache 관련 알람

#### 1. 높은 CPU 사용률 알람
```yaml
이름: goorm-popcorn-cache-dev-cache-high-cpu
메트릭: CPUUtilization
임계값: 80%
평가 기간: 2회 연속
주기: 5분
비교 연산자: GreaterThanThreshold
```

#### 2. 높은 메모리 사용률 알람
```yaml
이름: goorm-popcorn-cache-dev-cache-high-memory
메트릭: FreeableMemory
임계값: 100MB (100,000,000 bytes)
평가 기간: 2회 연속
주기: 5분
비교 연산자: LessThanThreshold
```

#### 3. 높은 연결 수 알람
```yaml
이름: goorm-popcorn-cache-dev-cache-high-connections
메트릭: CurrConnections
임계값: 50개
평가 기간: 2회 연속
주기: 5분
비교 연산자: GreaterThanThreshold
```

#### 4. 낮은 캐시 히트율 알람
```yaml
이름: goorm-popcorn-cache-dev-cache-low-hit-rate
메트릭: CacheHitRate
임계값: 0.8 (80%)
평가 기간: 3회 연속
주기: 5분
비교 연산자: LessThanThreshold
```
## CloudWatch Logs

### 로그 그룹 구성

#### ECS 서비스 로그 그룹 (8개)
```yaml
로그 그룹 패턴: /aws/ecs/goorm-popcorn-dev/{service-name}
보존 기간: 7일
서비스별 로그 그룹:
  - /aws/ecs/goorm-popcorn-dev/api-gateway
  - /aws/ecs/goorm-popcorn-dev/user-service
  - /aws/ecs/goorm-popcorn-dev/store-service
  - /aws/ecs/goorm-popcorn-dev/order-service
  - /aws/ecs/goorm-popcorn-dev/payment-service
  - /aws/ecs/goorm-popcorn-dev/payment-front
  - /aws/ecs/goorm-popcorn-dev/checkin-service
  - /aws/ecs/goorm-popcorn-dev/order-query
```

#### ECS Exec 로그 그룹
```yaml
로그 그룹: /aws/ecs/goorm-popcorn-dev/exec
용도: ECS Execute Command 세션 로그
보존 기간: 7일
암호화: 활성화
```

#### Kafka 로그 그룹
```yaml
로그 그룹: /aws/ec2/goorm-popcorn-dev/kafka
용도: EC2 Kafka 브로커 로그
보존 기간: 7일
상태: ⚠️ Kafka 인스턴스 STOPPED로 로그 미생성
```

#### VPC Flow Logs
```yaml
로그 그룹: /aws/vpc/flowlogs/goorm-popcorn-vpc-dev
용도: VPC 네트워크 트래픽 로그
보존 기간: 7일
```

## Container Insights

### 활성화된 기능
```yaml
클러스터: goorm-popcorn-dev-cluster
상태: 활성화 (containerInsights = enabled)
수집 메트릭:
  - 컨테이너별 CPU/Memory 사용률
  - 네트워크 I/O 메트릭
  - 디스크 I/O 메트릭
  - 태스크 및 서비스 레벨 메트릭
```

### Container Insights 메트릭
- **ECS/ContainerInsights**: 네임스페이스
- **수집 주기**: 1분
- **세분화 수준**: 태스크, 서비스, 클러스터

## 주요 모니터링 지표

### 🔴 Critical (즉시 대응 필요)

#### ALB 관련
- **응답 시간 > 1초**: 사용자 경험 저하
- **5xx 에러 > 5개/5분**: 서버 장애 발생
- **요청 수 급증**: DDoS 또는 트래픽 스파이크

#### ECS 서비스 관련
- **CPU 사용률 > 90%**: 성능 저하 위험
- **Memory 사용률 > 95%**: OOM 위험
- **태스크 재시작 빈발**: 애플리케이션 불안정

#### 데이터베이스 관련
- **RDS CPU > 80%**: 쿼리 최적화 필요
- **연결 수 > 80%**: 커넥션 풀 조정 필요
- **지연 시간 > 100ms**: 성능 이슈

### 🟡 Warning (주의 관찰)

#### 캐시 관련
- **캐시 히트율 < 80%**: 캐시 전략 재검토
- **ElastiCache CPU > 60%**: 용량 증설 고려
- **연결 수 > 30개**: 연결 관리 점검

#### 네트워크 관련
- **4xx 에러 > 10개/5분**: 클라이언트 요청 검토
- **네트워크 I/O 급증**: 대역폭 사용량 확인

### 🟢 Info (정기 점검)

#### 리소스 사용률
- **전체적인 CPU/Memory 트렌드**
- **스토리지 사용량 증가 패턴**
- **로그 볼륨 증가 추이**

## 모니터링 대시보드 활용법

### 1. 일일 점검 체크리스트
```
□ ALB 요청 수 및 응답 시간 확인
□ ECS 서비스 CPU/Memory 사용률 점검
□ RDS 성능 지표 확인
□ ElastiCache 히트율 및 성능 점검
□ 최근 에러 로그 검토
```

### 2. 주간 점검 체크리스트
```
□ 트래픽 패턴 분석
□ 리소스 사용률 트렌드 분석
□ 알람 발생 빈도 검토
□ 로그 보존 정책 점검
□ 비용 최적화 기회 탐색
```

### 3. 장애 대응 절차
```
1. 대시보드에서 전체 상황 파악
2. 알람 히스토리 확인
3. 해당 서비스 로그 상세 분석
4. 필요시 ECS Exec으로 컨테이너 접속
5. 복구 조치 후 모니터링 지속
```

## 로그 분석 쿼리

### 자주 사용하는 CloudWatch Insights 쿼리

#### 1. 에러 로그 분석
```sql
SOURCE '/aws/ecs/goorm-popcorn-dev/api-gateway'
| fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

#### 2. 응답 시간 분석
```sql
SOURCE '/aws/ecs/goorm-popcorn-dev/api-gateway'
| fields @timestamp, @message
| filter @message like /response_time/
| stats avg(response_time) by bin(5m)
```

#### 3. 특정 API 호출 분석
```sql
SOURCE '/aws/ecs/goorm-popcorn-dev/api-gateway'
| fields @timestamp, @message
| filter @message like /\/api\/orders/
| stats count() by bin(1h)
```

#### 4. 메모리 사용량 패턴
```sql
SOURCE '/aws/ecs/goorm-popcorn-dev/user-service'
| fields @timestamp, @message
| filter @message like /memory/
| sort @timestamp desc
```

## 알람 관리

### 현재 알람 상태
- **총 알람 수**: 7개
- **SNS 연동**: 비활성화 (dev 환경)
- **알람 액션**: 없음 (모니터링 목적만)

### 알람 임계값 조정 가이드

#### ALB 응답 시간
```
현재: 1.0초
권장 조정:
- 개발: 2.0초 (여유있게)
- 운영: 0.5초 (엄격하게)
```

#### ElastiCache CPU
```
현재: 80%
권장 조정:
- 높은 부하 예상시: 70%
- 안정적 운영시: 85%
```

### 알람 추가 권장사항

#### 1. ECS 서비스 알람
```yaml
- 태스크 재시작 빈도
- 서비스 배포 실패
- 헬스체크 실패율
```

#### 2. RDS 알람
```yaml
- 연결 수 임계값
- 스토리지 사용률
- 백업 실패
```

#### 3. 비즈니스 메트릭 알람
```yaml
- 주문 처리 실패율
- 결제 실패율
- 사용자 로그인 실패율
```
## 성능 최적화 모니터링

### 1. 응답 시간 최적화
```yaml
모니터링 지표:
  - ALB TargetResponseTime
  - ECS 서비스별 응답 시간
  - RDS 쿼리 실행 시간

최적화 방향:
  - 응답 시간 > 500ms 시 쿼리 최적화
  - 캐시 히트율 < 80% 시 캐시 전략 재검토
  - CPU 사용률 > 70% 시 스케일 아웃 고려
```

### 2. 리소스 사용률 최적화
```yaml
CPU 최적화:
  - 평균 사용률 < 30%: 인스턴스 다운사이징
  - 평균 사용률 > 70%: 스케일 아웃 또는 업사이징

Memory 최적화:
  - 평균 사용률 < 40%: 메모리 할당 조정
  - 평균 사용률 > 80%: 메모리 누수 점검

네트워크 최적화:
  - 대역폭 사용률 모니터링
  - 불필요한 네트워크 호출 최소화
```

### 3. 비용 최적화 모니터링
```yaml
FARGATE_SPOT 사용률:
  - SPOT 인스턴스 중단 빈도
  - 비용 절약 효과 측정

리소스 Right-sizing:
  - CPU/Memory 사용률 기반 최적 크기 산정
  - 미사용 리소스 식별
```

## 트러블슈팅 가이드

### 자주 발생하는 문제와 해결 방법

#### 1. 높은 응답 시간
```yaml
증상: ALB TargetResponseTime > 1초
원인 분석:
  - ECS 서비스 CPU/Memory 사용률 확인
  - RDS 성능 지표 확인
  - 캐시 히트율 확인

해결 방법:
  - 스케일 아웃 (태스크 수 증가)
  - 쿼리 최적화
  - 캐시 전략 개선
```

#### 2. 높은 에러율
```yaml
증상: 4xx/5xx 에러 급증
원인 분석:
  - 애플리케이션 로그 상세 분석
  - 데이터베이스 연결 상태 확인
  - 외부 API 의존성 확인

해결 방법:
  - 애플리케이션 코드 수정
  - 데이터베이스 연결 풀 조정
  - 서킷 브레이커 패턴 적용
```

#### 3. 메모리 부족
```yaml
증상: ECS 태스크 재시작 빈발
원인 분석:
  - 메모리 사용률 트렌드 분석
  - 메모리 누수 패턴 확인
  - GC 로그 분석

해결 방법:
  - 메모리 할당량 증가
  - 애플리케이션 메모리 최적화
  - JVM 튜닝 (Java 서비스의 경우)
```

#### 4. 캐시 성능 저하
```yaml
증상: ElastiCache 히트율 < 80%
원인 분석:
  - 캐시 키 패턴 분석
  - TTL 설정 검토
  - 캐시 무효화 패턴 확인

해결 방법:
  - 캐시 키 전략 재설계
  - TTL 최적화
  - 캐시 워밍 전략 적용
```

## 모니터링 도구 및 접근 방법

### AWS Console 접근
```yaml
CloudWatch Dashboard:
  - AWS Console > CloudWatch > Dashboards
  - 대시보드명: goorm-popcorn-dev-overview

CloudWatch Logs:
  - AWS Console > CloudWatch > Log groups
  - 로그 그룹별 실시간 모니터링

CloudWatch Alarms:
  - AWS Console > CloudWatch > Alarms
  - 알람 상태 및 히스토리 확인
```

### CLI를 통한 모니터링
```bash
# 최근 알람 상태 확인
aws cloudwatch describe-alarms \
  --alarm-names "goorm-popcorn-alb-dev-alb-high-response-time"

# 메트릭 데이터 조회
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/goorm-popcorn-alb-dev/87b8f470c6617444 \
  --start-time 2026-01-28T00:00:00Z \
  --end-time 2026-01-28T23:59:59Z \
  --period 300 \
  --statistics Average

# 로그 조회
aws logs filter-log-events \
  --log-group-name "/aws/ecs/goorm-popcorn-dev/api-gateway" \
  --filter-pattern "ERROR" \
  --start-time 1643328000000
```

### 써드파티 도구 연동
```yaml
Grafana 연동:
  - CloudWatch 데이터소스 설정
  - 커스텀 대시보드 구성

Prometheus 연동:
  - CloudWatch Exporter 사용
  - 메트릭 수집 및 알람 설정

ELK Stack 연동:
  - CloudWatch Logs → Elasticsearch
  - Kibana 대시보드 구성
```

## 보안 및 컴플라이언스

### 로그 보안
```yaml
암호화:
  - CloudWatch Logs 암호화 활성화
  - 민감 정보 마스킹 적용

접근 제어:
  - IAM 정책을 통한 로그 접근 제한
  - 로그 그룹별 세분화된 권한 설정

보존 정책:
  - 개발 환경: 7일 보존
  - 운영 환경: 30일 이상 권장
```

### 모니터링 데이터 거버넌스
```yaml
데이터 분류:
  - 개인정보 포함 로그 별도 관리
  - 비즈니스 크리티컬 메트릭 식별

백업 및 아카이브:
  - 중요 메트릭 데이터 장기 보존
  - S3로 로그 아카이브 설정
```

## 향후 개선 계획

### 단기 개선 사항 (1-2개월)
```yaml
1. 비즈니스 메트릭 추가:
   - 주문 성공률
   - 결제 완료율
   - 사용자 활성도

2. 알람 고도화:
   - 복합 조건 알람
   - 동적 임계값 적용
   - 알람 피로도 감소

3. 로그 분석 강화:
   - 구조화된 로깅 적용
   - 로그 집계 및 분석 자동화
```

### 중기 개선 사항 (3-6개월)
```yaml
1. APM 도구 도입:
   - 분산 트레이싱
   - 애플리케이션 성능 모니터링
   - 사용자 경험 모니터링

2. 예측적 모니터링:
   - 머신러닝 기반 이상 탐지
   - 용량 계획 자동화
   - 성능 예측 모델

3. 자동화 강화:
   - 자동 복구 시스템
   - 인시던트 대응 자동화
   - 보고서 자동 생성
```

## 참고 자료

- [AWS CloudWatch 사용자 가이드](https://docs.aws.amazon.com/cloudwatch/)
- [ECS Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [CloudWatch Logs Insights 쿼리 문법](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [AWS Well-Architected Framework - 운영 우수성](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/)

---

**문서 버전**: 1.0  
**최종 업데이트**: 2026-01-28  
**작성자**: DevOps Team  
**검토자**: Infrastructure Team