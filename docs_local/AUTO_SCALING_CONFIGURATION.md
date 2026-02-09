# Popcorn MSA Auto Scaling 설정 문서

## 개요

본 문서는 Popcorn MSA Dev 환경의 ECS Fargate 서비스에 대한 Auto Scaling 설정을 상세히 기술합니다.

## Auto Scaling 정책 요약

### 전체 서비스 Auto Scaling 현황

| 서비스 | Min | Max | Desired | CPU 임계값 | Memory 임계값 | 현재 상태 |
|--------|-----|-----|---------|------------|---------------|-----------|
| **api-gateway** | 1 | 2 | 1 | 70% | 80% | 1개 실행 |
| **user-service** | 1 | 3 | 1 | 70% | 80% | 1개 실행 |
| **store-service** | 1 | 3 | 3 | 70% | 80% | 3개 실행 (최대) |
| **order-service** | 1 | 3 | 1 | 70% | 80% | 1개 실행 |
| **payment-service** | 1 | 3 | 1 | 70% | 80% | 1개 실행 |
| **payment-front** | 1 | 2 | 1 | 70% | 80% | 1개 실행 |
| **checkin-service** | 1 | 2 | 2 | 70% | 80% | 2개 실행 (최대) |
| **order-query** | 1 | 2 | 2 | 70% | 80% | 2개 실행 (최대) |

## Auto Scaling 정책 상세

### 1. 스케일링 방식
- **정책 타입**: Target Tracking Scaling (목표 추적 스케일링)
- **서비스 네임스페이스**: `ecs`
- **확장 가능한 차원**: `ecs:service:DesiredCount`

### 2. CPU 기반 스케일링 정책
```yaml
정책명: {service-name}-cpu-autoscaling
메트릭: ECSServiceAverageCPUUtilization
목표값: 70%
Scale Out Cooldown: 300초 (5분)
Scale In Cooldown: 300초 (5분)
Scale In 비활성화: false
```

### 3. Memory 기반 스케일링 정책
```yaml
정책명: {service-name}-memory-autoscaling
메트릭: ECSServiceAverageMemoryUtilization
목표값: 80%
Scale Out Cooldown: 300초 (5분)
Scale In Cooldown: 300초 (5분)
Scale In 비활성화: false
```

## 스케일링 동작 원리

### Scale Out (확장) 조건
다음 조건 중 하나라도 만족 시 태스크 추가:
- CPU 평균 사용률 > 70%
- Memory 평균 사용률 > 80%

### Scale In (축소) 조건
다음 조건을 모두 만족 시 태스크 제거:
- CPU 평균 사용률 < 70%
- Memory 평균 사용률 < 80%

### Cooldown 정책
- **Scale Out Cooldown**: 300초 (5분)
  - 스케일 아웃 후 다음 스케일 아웃까지 대기 시간
- **Scale In Cooldown**: 300초 (5분)
  - 스케일 인 후 다음 스케일 인까지 대기 시간
## Capacity Provider 전략

### FARGATE vs FARGATE_SPOT 배분
```yaml
FARGATE (안정성 우선):
  - Base: min_capacity 만큼 보장
  - Weight: 1
  - 용도: 최소 용량 보장

FARGATE_SPOT (비용 절약):
  - Base: 0 (보장 없음)
  - Weight: 1 (dev 환경)
  - 용도: 추가 용량 확장 시 사용
```

## 서비스별 상세 설정

### 1. API Gateway
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-2개 태스크
특징: ALB 직접 연결, 외부 트래픽 처리
현재 상태: 1개 태스크 실행
```

### 2. User Service
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-3개 태스크
특징: 사용자 관리 서비스
현재 상태: 1개 태스크 실행
```

### 3. Store Service
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-3개 태스크
특징: 매장 관리, 높은 부하 예상
현재 상태: 3개 태스크 실행 (최대치)
```

### 4. Order Service
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-3개 태스크
특징: 주문 처리 서비스
현재 상태: 1개 태스크 실행
```

### 5. Payment Service
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-3개 태스크
특징: 결제 처리 서비스
현재 상태: 1개 태스크 실행
```

### 6. Payment Front
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-2개 태스크
특징: 결제 프론트엔드, ALB 직접 연결
현재 상태: 1개 태스크 실행
```

### 7. Checkin Service
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-2개 태스크
특징: QR 체크인 서비스
현재 상태: 2개 태스크 실행 (최대치)
```

### 8. Order Query
```yaml
리소스: 256 CPU, 512 MB Memory
스케일링: 1-2개 태스크
특징: 주문 조회 서비스 (CQRS 읽기 모델)
현재 상태: 2개 태스크 실행 (최대치)
```

## CloudWatch 알람 연동

### 자동 생성되는 알람
각 서비스마다 다음 알람이 자동 생성됩니다:

#### CPU 기반 알람
- **AlarmHigh**: CPU 사용률 > 70% 시 Scale Out 트리거
- **AlarmLow**: CPU 사용률 < 70% 시 Scale In 트리거

#### Memory 기반 알람
- **AlarmHigh**: Memory 사용률 > 80% 시 Scale Out 트리거
- **AlarmLow**: Memory 사용률 < 80% 시 Scale In 트리거

### 알람 명명 규칙
```
TargetTracking-service/{cluster-name}/{service-name}-AlarmHigh-{uuid}
TargetTracking-service/{cluster-name}/{service-name}-AlarmLow-{uuid}
```
## 모니터링 및 관리

### CloudWatch 메트릭
다음 메트릭을 통해 Auto Scaling 상태를 모니터링할 수 있습니다:

- `ECSServiceAverageCPUUtilization`
- `ECSServiceAverageMemoryUtilization`
- `DesiredCount`
- `RunningTaskCount`
- `PendingTaskCount`

### 대시보드 확인
- **CloudWatch Dashboard**: `goorm-popcorn-dev-overview`
- **ECS 콘솔**: 서비스별 메트릭 및 태스크 상태 확인

## 비용 최적화 전략

### 1. FARGATE_SPOT 활용
- 추가 용량 확장 시 FARGATE_SPOT 우선 사용
- 최대 70% 비용 절약 가능
- 중단 위험이 있으나 최소 용량은 FARGATE로 보장

### 2. 보수적인 임계값
- CPU 70%, Memory 80%로 여유있는 설정
- 불필요한 스케일링 방지
- 안정적인 서비스 운영

### 3. 적절한 Cooldown
- 5분 Cooldown으로 빈번한 스케일링 방지
- 비용 효율성과 응답성의 균형

## 운영 가이드

### 수동 스케일링
긴급 상황 시 AWS CLI를 통한 수동 스케일링:

```bash
# 특정 서비스의 desired count 변경
aws ecs update-service \
  --cluster goorm-popcorn-dev-cluster \
  --service goorm-popcorn-dev-api-gateway \
  --desired-count 2
```

### Auto Scaling 일시 중단
```bash
# Auto Scaling 정책 일시 중단
aws application-autoscaling put-scaling-policy \
  --policy-name goorm-popcorn-dev-api-gateway-cpu-autoscaling \
  --service-namespace ecs \
  --resource-id service/goorm-popcorn-dev-cluster/goorm-popcorn-dev-api-gateway \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://suspended-policy.json
```

### 임계값 조정
Terraform 코드에서 `cpu_target_value`, `memory_target_value` 수정 후 재배포:

```hcl
services = {
  "api-gateway" = {
    cpu_target_value    = 60  # 70에서 60으로 변경
    memory_target_value = 70  # 80에서 70으로 변경
    # ... 기타 설정
  }
}
```

## 트러블슈팅

### 자주 발생하는 문제

#### 1. 스케일링이 작동하지 않는 경우
- CloudWatch 메트릭 확인
- IAM 권한 확인 (`AWSServiceRoleForApplicationAutoScaling_ECSService`)
- 서비스 상태 확인 (STABLE 상태여야 함)

#### 2. 과도한 스케일링 발생
- Cooldown 시간 증가 고려
- 임계값 조정 검토
- 애플리케이션 성능 최적화

#### 3. FARGATE_SPOT 중단 빈발
- FARGATE 비중 증가 고려
- 중요 서비스는 FARGATE만 사용 검토

## 성능 최적화 권장사항

### 1. 애플리케이션 레벨
- JVM 힙 메모리 최적화
- 커넥션 풀 설정 최적화
- 불필요한 로깅 최소화

### 2. 인프라 레벨
- 적절한 CPU/Memory 비율 설정
- Health Check 최적화
- 로드밸런서 설정 최적화

### 3. 모니터링 강화
- 커스텀 메트릭 추가
- 알람 임계값 세분화
- 성능 트렌드 분석

## 참고 자료

- [AWS ECS Auto Scaling 공식 문서](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-auto-scaling.html)
- [AWS Application Auto Scaling 사용자 가이드](https://docs.aws.amazon.com/autoscaling/application/userguide/what-is-application-auto-scaling.html)
- [FARGATE vs FARGATE_SPOT 비교](https://aws.amazon.com/fargate/pricing/)

---

**문서 버전**: 1.0  
**최종 업데이트**: 2026-01-28  
**작성자**: DevOps Team  
**검토자**: Infrastructure Team