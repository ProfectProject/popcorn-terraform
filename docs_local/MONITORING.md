# CloudWatch 모니터링 가이드

## 개요

이 문서는 Popcorn MSA 인프라의 CloudWatch 모니터링 설정과 운영 가이드를 제공합니다.

## 현재 모니터링 범위

### ✅ 기본 모니터링 (현재 활성화)

#### 1. ECS Fargate 서비스
- **로그 수집**: 각 마이크로서비스별 CloudWatch 로그 그룹
  ```
  /aws/ecs/goorm-popcorn-dev/api-gateway
  /aws/ecs/goorm-popcorn-dev/user-service
  /aws/ecs/goorm-popcorn-dev/store-service
  /aws/ecs/goorm-popcorn-dev/order-service
  /aws/ecs/goorm-popcorn-dev/payment-service
  /aws/ecs/goorm-popcorn-dev/checkin-service
  /aws/ecs/goorm-popcorn-dev/order-query
  ```
- **Container Insights**: 활성화됨
- **오토스케일링**: CPU/Memory 기반 자동 스케일링
- **로그 보존**: 7일 (dev 환경)

#### 2. RDS PostgreSQL
- **로그 내보내기**: `postgresql`, `upgrade` 로그
- **Performance Insights**: 활성화
- **Enhanced Monitoring**: 설정 가능 (현재 비활성화)

#### 3. EC2 Kafka
- **로그 수집**: `/aws/ec2/kafka-dev`
- **SSM 에이전트**: CloudWatch 에이전트 설치 가능

### 🔧 추가 모니터링 (설정 가능)

#### 1. Application Load Balancer (ALB)
- **액세스 로그**: S3 버킷에 저장
- **메트릭 알람**: 응답시간, 4xx/5xx 에러율
- **대시보드**: 요청 수, 응답시간, 에러율 시각화

#### 2. ElastiCache (Valkey)
- **메트릭 알람**: CPU, 메모리, 연결 수, 캐시 히트율
- **성능 모니터링**: 실시간 메트릭 추적

#### 3. VPC 네트워크
- **VPC Flow Logs**: 네트워크 트래픽 분석
- **보안 모니터링**: 거부된 트래픽 알람

#### 4. 분산 추적 (X-Ray)
- **서비스 맵**: 마이크로서비스 간 호출 관계
- **성능 분석**: 응답시간, 에러율 추적

## 모니터링 설정 방법

### 1. 기본 모니터링 활성화

현재 dev 환경에서는 기본 모니터링이 이미 활성화되어 있습니다.

### 2. 추가 모니터링 활성화

#### ALB 모니터링 활성화
```hcl
# envs/dev/main.tf에 추가
module "alb" {
  source = "../../modules/alb"
  
  # 기존 설정...
  
  # 모니터링 설정
  enable_access_logs   = true
  access_logs_bucket   = "your-alb-logs-bucket"
  access_logs_prefix   = "alb"
  sns_topic_arn       = module.monitoring.sns_topic_arn
}
```

#### 통합 모니터링 대시보드
```hcl
# envs/dev/main.tf에 추가
module "monitoring" {
  source = "../../modules/monitoring"
  
  name                    = var.name
  region                  = var.region
  alb_arn_suffix         = module.alb.alb_arn_suffix
  rds_instance_id        = module.rds.instance_id
  elasticache_cluster_id = module.elasticache.cluster_id
  alert_email_addresses  = ["admin@yourcompany.com"]
  
  tags = var.tags
}
```

#### VPC Flow Logs 활성화
```hcl
# envs/dev/main.tf에서 VPC 모듈 수정
module "vpc" {
  source = "../../modules/vpc"
  
  # 기존 설정...
  
  # Flow Logs 설정
  enable_flow_logs         = true
  flow_logs_retention_days = 7
  sns_topic_arn           = module.monitoring.sns_topic_arn
}
```

#### X-Ray 분산 추적
```hcl
# envs/dev/main.tf에 추가
module "xray" {
  source = "../../modules/xray"
  
  name            = var.name
  log_group_names = [
    "/aws/ecs/${var.name}/api-gateway",
    "/aws/ecs/${var.name}/user-service",
    "/aws/ecs/${var.name}/store-service"
  ]
  
  tags = var.tags
}
```

## 알람 설정

### 중요 알람 목록

#### ALB 알람
- **높은 응답시간**: 평균 응답시간 > 1초
- **4xx 에러**: 5분간 10개 이상
- **5xx 에러**: 5분간 5개 이상

#### ECS 알람
- **CPU 사용률**: 평균 > 80%
- **메모리 사용률**: 평균 > 80%
- **서비스 불안정**: Desired Count와 Running Count 불일치

#### RDS 알람
- **CPU 사용률**: 평균 > 80%
- **연결 수**: 최대 연결 수의 80% 초과
- **디스크 공간**: 사용 가능 공간 < 2GB

#### ElastiCache 알람
- **CPU 사용률**: 평균 > 80%
- **메모리 사용률**: 사용 가능 메모리 < 100MB
- **캐시 히트율**: < 80%

### 알람 알림 설정

```bash
# SNS 토픽 구독 (이메일)
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-2:ACCOUNT:goorm-popcorn-dev-alerts \
  --protocol email \
  --notification-endpoint your-email@company.com
```

## 대시보드 활용

### CloudWatch 대시보드 접근
1. AWS Console → CloudWatch → Dashboards
2. `goorm-popcorn-dev-overview` 대시보드 선택

### 주요 위젯
- **ALB 메트릭**: 요청 수, 응답시간, 에러율
- **ECS 메트릭**: CPU/메모리 사용률, 서비스 상태
- **RDS 메트릭**: 성능, 연결 수, 지연시간
- **ElastiCache 메트릭**: 성능, 히트율, 연결 상태
- **최근 에러 로그**: 애플리케이션 에러 로그 실시간 조회

## 로그 분석

### CloudWatch Logs Insights 쿼리 예제

#### 애플리케이션 에러 조회
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

#### API 응답시간 분석
```sql
fields @timestamp, @message
| filter @message like /response_time/
| stats avg(response_time), max(response_time), min(response_time) by bin(5m)
```

#### 특정 서비스 로그 필터링
```sql
SOURCE '/aws/ecs/goorm-popcorn-dev/api-gateway'
| fields @timestamp, @message
| filter @message like /user-service/
| sort @timestamp desc
```

## 비용 최적화

### 로그 보존 정책
- **Dev 환경**: 7일
- **Staging 환경**: 14일
- **Production 환경**: 30일

### 메트릭 보존
- **상세 메트릭**: 15개월
- **1분 메트릭**: 15일
- **5분 메트릭**: 63일
- **1시간 메트릭**: 455일

### 비용 절약 팁
1. **로그 필터링**: 불필요한 로그 제외
2. **메트릭 선택**: 필요한 메트릭만 수집
3. **보존 기간 조정**: 환경별 적절한 보존 기간 설정

## 트러블슈팅

### 일반적인 문제

#### 1. 로그가 보이지 않는 경우
- ECS 태스크 정의에서 로그 드라이버 설정 확인
- IAM 역할에 CloudWatch Logs 권한 확인
- 로그 그룹 존재 여부 확인

#### 2. 메트릭이 수집되지 않는 경우
- Container Insights 활성화 상태 확인
- CloudWatch 에이전트 설치 및 설정 확인
- 네트워크 연결 상태 확인

#### 3. 알람이 작동하지 않는 경우
- SNS 토픽 구독 상태 확인
- 알람 임계값 및 조건 검토
- 메트릭 데이터 수집 상태 확인

### 유용한 AWS CLI 명령어

```bash
# 로그 그룹 목록 조회
aws logs describe-log-groups --log-group-name-prefix "/aws/ecs/goorm-popcorn"

# 최근 로그 스트림 조회
aws logs describe-log-streams --log-group-name "/aws/ecs/goorm-popcorn-dev/api-gateway" --order-by LastEventTime --descending

# 알람 상태 조회
aws cloudwatch describe-alarms --alarm-names "goorm-popcorn-dev-alb-high-response-time"

# 메트릭 데이터 조회
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/goorm-popcorn-alb-dev/87b8f470c6617444 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## 모니터링 체크리스트

### 일일 점검 항목
- [ ] 전체 서비스 상태 확인
- [ ] 에러 로그 검토
- [ ] 성능 메트릭 확인
- [ ] 알람 상태 점검

### 주간 점검 항목
- [ ] 리소스 사용률 트렌드 분석
- [ ] 로그 보존 정책 검토
- [ ] 비용 사용량 확인
- [ ] 알람 임계값 조정 검토

### 월간 점검 항목
- [ ] 모니터링 설정 최적화
- [ ] 새로운 메트릭 추가 검토
- [ ] 대시보드 개선
- [ ] 문서 업데이트

## 참고 자료

- [AWS CloudWatch 사용자 가이드](https://docs.aws.amazon.com/cloudwatch/)
- [Container Insights 설정 가이드](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [X-Ray 개발자 가이드](https://docs.aws.amazon.com/xray/)
- [VPC Flow Logs 가이드](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)