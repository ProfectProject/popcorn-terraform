# CloudWatch 모니터링 강화 요약서

## 📋 개요

이 문서는 Popcorn MSA 인프라에 추가된 CloudWatch 모니터링 강화 사항을 종합적으로 정리합니다.

---

## 🔍 현재 모니터링 상태 분석

### Before (기존 모니터링)
| 서비스 | 로그 수집 | 메트릭 모니터링 | 알람 | 대시보드 | 상태 |
|--------|-----------|----------------|------|----------|------|
| ECS Fargate | ✅ | ✅ Container Insights | ✅ Auto Scaling | ❌ | 양호 |
| RDS PostgreSQL | ✅ | ✅ Performance Insights | ❌ | ❌ | 보통 |
| EC2 Kafka | ✅ | ❌ | ❌ | ❌ | 미흡 |
| ALB | ❌ | ✅ 기본 메트릭 | ❌ | ❌ | 미흡 |
| ElastiCache | ❌ | ✅ 기본 메트릭 | ❌ | ❌ | 미흡 |
| VPC 네트워크 | ❌ | ❌ | ❌ | ❌ | 없음 |

### After (모니터링 강화 후)
| 서비스 | 로그 수집 | 메트릭 모니터링 | 알람 | 대시보드 | 상태 |
|--------|-----------|----------------|------|----------|------|
| ECS Fargate | ✅ | ✅ Container Insights | ✅ Auto Scaling | ✅ | 우수 |
| RDS PostgreSQL | ✅ | ✅ Performance Insights | ✅ 추가 예정 | ✅ | 우수 |
| EC2 Kafka | ✅ | ✅ 시스템 메트릭 | ✅ 추가 예정 | ✅ | 양호 |
| ALB | ✅ 액세스 로그 | ✅ 성능 메트릭 | ✅ 3개 알람 | ✅ | 우수 |
| ElastiCache | ❌ | ✅ 성능 메트릭 | ✅ 4개 알람 | ✅ | 우수 |
| VPC 네트워크 | ✅ Flow Logs | ✅ 네트워크 메트릭 | ✅ 보안 알람 | ✅ | 양호 |

---

## 🆕 추가된 모니터링 구성요소

### 1. 통합 모니터링 모듈 (`modules/monitoring/`)

#### 📁 구성 파일
- `main.tf`: 대시보드, SNS 토픽 정의
- `variables.tf`: 설정 변수
- `outputs.tf`: SNS ARN, 대시보드 URL 출력

#### 🎯 주요 기능
- **통합 CloudWatch 대시보드**: 전체 인프라 상태 시각화
- **SNS 알림 시스템**: 이메일 알림 (선택적)
- **위젯 구성**:
  - ALB 메트릭 (요청수, 응답시간, 에러율)
  - ECS 서비스 메트릭 (CPU, 메모리)
  - RDS 메트릭 (성능, 연결수, 지연시간)
  - ElastiCache 메트릭 (CPU, 메모리, 히트율)
  - 최근 애플리케이션 에러 로그

### 2. ALB 모니터링 강화 (`modules/alb/cloudwatch.tf`)

#### 📁 새로 추가된 파일
- `cloudwatch.tf`: ALB 모니터링 전용 설정

#### 🎯 추가된 기능
| 기능 | 설명 | 설정 |
|------|------|------|
| **S3 액세스 로그** | ALB 요청 로그 저장 | 선택적 활성화 |
| **로그 Lifecycle** | 30일 후 자동 삭제 | 자동 적용 |
| **응답시간 알람** | 평균 응답시간 > 1초 | 5분간 2회 연속 |
| **4xx 에러 알람** | 4xx 에러 > 10개 | 5분간 2회 연속 |
| **5xx 에러 알람** | 5xx 에러 > 5개 | 5분간 1회 |

#### 📊 모니터링 메트릭
- `RequestCount`: 요청 수
- `TargetResponseTime`: 응답 시간
- `HTTPCode_Target_2XX_Count`: 성공 응답
- `HTTPCode_Target_4XX_Count`: 클라이언트 에러
- `HTTPCode_Target_5XX_Count`: 서버 에러

### 3. ElastiCache 모니터링 강화 (`modules/elasticache/cloudwatch.tf`)

#### 📁 새로 추가된 파일
- `cloudwatch.tf`: ElastiCache 모니터링 전용 설정

#### 🎯 추가된 알람
| 알람명 | 메트릭 | 임계값 | 조건 |
|--------|--------|--------|------|
| **CPU 사용률** | `CPUUtilization` | > 80% | 5분간 2회 연속 |
| **메모리 사용률** | `FreeableMemory` | < 100MB | 5분간 2회 연속 |
| **연결 수** | `CurrConnections` | > 50개 | 5분간 2회 연속 |
| **캐시 히트율** | `CacheHitRate` | < 80% | 5분간 3회 연속 |

#### 📊 모니터링 메트릭
- `CPUUtilization`: CPU 사용률
- `FreeableMemory`: 사용 가능 메모리
- `CurrConnections`: 현재 연결 수
- `CacheHitRate`: 캐시 히트율
- `NetworkBytesIn/Out`: 네트워크 트래픽

### 4. VPC 네트워크 모니터링 (`modules/vpc/flow-logs.tf`)

#### 📁 새로 추가된 파일
- `flow-logs.tf`: VPC Flow Logs 및 네트워크 모니터링

#### 🎯 추가된 기능
| 기능 | 설명 | 보존 기간 |
|------|------|----------|
| **VPC Flow Logs** | 모든 네트워크 트래픽 로깅 | 7일 (dev) |
| **IAM 역할** | Flow Logs 전용 권한 | - |
| **메트릭 필터** | 거부된 트래픽 감지 | - |
| **보안 알람** | 비정상 트래픽 알림 | > 100건/5분 |

#### 📊 수집 데이터
- 소스/대상 IP 주소
- 포트 번호
- 프로토콜
- 허용/거부 상태
- 패킷 수 및 바이트 수

### 5. X-Ray 분산 추적 모듈 (`modules/xray/`)

#### 📁 구성 파일
- `main.tf`: X-Ray 설정
- `variables.tf`: 설정 변수
- `outputs.tf`: 샘플링 규칙 ARN

#### 🎯 주요 기능
- **샘플링 규칙**: 10% 트래픽 추적
- **암호화 설정**: KMS 키 기반 암호화
- **CloudWatch Insights 쿼리**: 에러 및 지연시간 분석

---

## 💰 비용 분석

### 월간 예상 비용 (dev 환경)

#### 기본 모니터링 (SNS 없이)
| 서비스 | 항목 | 사용량 | 단가 | 월 비용 |
|--------|------|--------|------|---------|
| **CloudWatch Logs** | 로그 수집 | 5GB | $0.50/GB | $2.50 |
| **CloudWatch Metrics** | 기본 메트릭 | 무료 | $0.00 | $0.00 |
| **CloudWatch Alarms** | 알람 | 10개 | $0.10/개 | $1.00 |
| **CloudWatch Dashboards** | 대시보드 | 1개 | $3.00/개 | $3.00 |
| **VPC Flow Logs** | 로그 수집 | 1GB | $0.50/GB | $0.50 |
| **소계** | | | | **$7.00** |

#### 고급 모니터링 (SNS + 액세스 로그 포함)
| 서비스 | 항목 | 사용량 | 단가 | 월 비용 |
|--------|------|--------|------|---------|
| **기본 모니터링** | 위 항목들 | - | - | $7.00 |
| **S3 Storage** | ALB 액세스 로그 | 10GB | $0.023/GB | $0.23 |
| **SNS** | 이메일 알림 | 1,000건 | $0.50/1K | $0.50 |
| **X-Ray** | 분산 추적 | 100K 추적 | $5.00/1M | $0.50 |
| **소계** | | | | **$8.23** |

### 환경별 비용 비교

| 환경 | 기본 모니터링 | 고급 모니터링 | 차이 |
|------|---------------|---------------|------|
| **Dev** | $7.00 | $8.23 | +$1.23 |
| **Staging** | $12.00 | $15.50 | +$3.50 |
| **Production** | $25.00 | $35.00 | +$10.00 |

### 비용 최적화 방안

#### 1. 로그 보존 기간 조정
- **Dev**: 7일 → 월 $2.50 절약
- **Staging**: 14일 → 월 $5.00 절약
- **Production**: 30일 유지

#### 2. 선택적 기능 활성화
- **ALB 액세스 로그**: 필요시에만 활성화
- **VPC Flow Logs**: 보안 요구사항에 따라 선택
- **X-Ray**: 성능 분석 필요시에만 사용

#### 3. 알람 최적화
- **중복 알람 제거**: 유사한 알람 통합
- **임계값 조정**: 실제 운영 데이터 기반 튜닝

---

## 🚀 배포 가이드

### 1단계: 기본 모니터링 활성화

#### terraform.tfvars 설정
```hcl
# 기본 모니터링 (SNS 없이)
enable_alb_access_logs = false
enable_vpc_flow_logs = false
```

#### main.tf에 모듈 추가
```hcl
module "monitoring" {
  source = "../../modules/monitoring"
  
  name                    = var.name
  region                  = var.region
  alb_arn_suffix         = module.alb.alb_arn_suffix
  rds_instance_id        = module.rds.instance_id
  elasticache_cluster_id = module.elasticache.cluster_id
  
  enable_sns_alerts = false
  
  tags = var.tags
}
```

### 2단계: 고급 모니터링 활성화

#### terraform.tfvars 설정
```hcl
# 고급 모니터링 (SNS 포함)
alert_email_addresses = ["admin@company.com"]
enable_alb_access_logs = true
alb_access_logs_bucket = "goorm-popcorn-alb-logs-dev"
enable_vpc_flow_logs = true
vpc_flow_logs_retention_days = 7
```

#### main.tf 업데이트
```hcl
module "monitoring" {
  source = "../../modules/monitoring"
  
  # ... 기본 설정 ...
  
  enable_sns_alerts     = true
  alert_email_addresses = var.alert_email_addresses
  
  tags = var.tags
}

# ALB 모듈 업데이트
module "alb" {
  source = "../../modules/alb"
  
  # ... 기존 설정 ...
  
  enable_access_logs       = var.enable_alb_access_logs
  access_logs_bucket       = var.alb_access_logs_bucket
  enable_cloudwatch_alarms = true
  sns_topic_arn           = module.monitoring.sns_topic_arn
}

# VPC 모듈 업데이트
module "vpc" {
  source = "../../modules/vpc"
  
  # ... 기존 설정 ...
  
  enable_flow_logs         = var.enable_vpc_flow_logs
  flow_logs_retention_days = var.vpc_flow_logs_retention_days
  sns_topic_arn           = module.monitoring.sns_topic_arn
}
```

### 3단계: 배포 실행

```bash
# 설정 검증
terraform validate

# 변경사항 확인
terraform plan

# 단계별 배포
terraform apply -target=module.monitoring
terraform apply -target=module.alb
terraform apply -target=module.vpc

# 전체 배포
terraform apply
```

---

## 📊 모니터링 대시보드 활용

### CloudWatch 대시보드 접근
1. AWS Console → CloudWatch → Dashboards
2. `goorm-popcorn-dev-overview` 선택

### 주요 위젯 설명

#### 1. ALB 성능 위젯
- **요청 수**: 시간당 처리된 요청 수
- **응답 시간**: 평균 응답 시간 추이
- **에러율**: 2xx, 4xx, 5xx 응답 비율

#### 2. ECS 서비스 위젯
- **CPU 사용률**: 각 서비스별 CPU 사용률
- **메모리 사용률**: 각 서비스별 메모리 사용률
- **서비스 상태**: Running/Pending 태스크 수

#### 3. RDS 성능 위젯
- **CPU 사용률**: 데이터베이스 CPU 사용률
- **연결 수**: 활성 데이터베이스 연결 수
- **지연시간**: 읽기/쓰기 지연시간

#### 4. ElastiCache 위젯
- **CPU 사용률**: 캐시 노드 CPU 사용률
- **메모리 사용률**: 사용 가능 메모리
- **히트율**: 캐시 히트율 추이

#### 5. 에러 로그 위젯
- **최근 에러**: 실시간 애플리케이션 에러 로그
- **필터링**: ERROR 레벨 로그만 표시

---

## 🔔 알람 및 알림 설정

### 설정된 알람 목록

#### ALB 알람 (3개)
1. **높은 응답시간**: > 1초, 5분간 2회 연속
2. **4xx 에러 급증**: > 10개/5분, 2회 연속
3. **5xx 에러 발생**: > 5개/5분, 1회

#### ElastiCache 알람 (4개)
1. **CPU 과부하**: > 80%, 5분간 2회 연속
2. **메모리 부족**: < 100MB, 5분간 2회 연속
3. **연결 수 과다**: > 50개, 5분간 2회 연속
4. **캐시 히트율 저하**: < 80%, 5분간 3회 연속

#### VPC 보안 알람 (1개)
1. **비정상 트래픽**: 거부된 트래픽 > 100건/5분

### 알림 채널 설정

#### 이메일 알림 (SNS 활성화시)
- **구독 확인**: 이메일에서 "Confirm subscription" 클릭 필요
- **알림 형식**: JSON 형태의 상세 알람 정보
- **즉시 알림**: 알람 상태 변경시 실시간 전송

#### 추가 통합 가능한 서비스
- **Slack**: SNS → Lambda → Slack Webhook
- **PagerDuty**: SNS → PagerDuty Integration
- **Microsoft Teams**: SNS → Logic Apps → Teams

---

## 🛠️ 운영 및 유지보수

### 일일 점검 항목
- [ ] 대시보드에서 전체 서비스 상태 확인
- [ ] 활성 알람 상태 점검
- [ ] 에러 로그 검토 (ERROR 레벨)
- [ ] 성능 메트릭 이상치 확인

### 주간 점검 항목
- [ ] 알람 임계값 적정성 검토
- [ ] 로그 보존 정책 확인
- [ ] 비용 사용량 모니터링
- [ ] 대시보드 위젯 최적화

### 월간 점검 항목
- [ ] 모니터링 설정 전체 검토
- [ ] 새로운 메트릭 추가 검토
- [ ] 비용 최적화 방안 검토
- [ ] 문서 업데이트

### 문제 해결 가이드

#### 알람이 작동하지 않는 경우
1. **메트릭 데이터 확인**: CloudWatch Metrics에서 데이터 수집 상태 확인
2. **알람 조건 검토**: 임계값 및 평가 기간 적정성 검토
3. **SNS 구독 상태**: 이메일 구독 승인 여부 확인

#### 대시보드가 표시되지 않는 경우
1. **권한 확인**: CloudWatch 대시보드 읽기 권한 확인
2. **리전 확인**: 올바른 AWS 리전 선택 여부 확인
3. **위젯 설정**: 메트릭 이름 및 차원 정확성 확인

---

## 📈 향후 개선 계획

### 단기 계획 (1-3개월)
1. **RDS 알람 추가**: CPU, 연결수, 디스크 공간 알람
2. **ECS 서비스별 알람**: 각 마이크로서비스별 세부 알람
3. **커스텀 메트릭**: 비즈니스 메트릭 추가

### 중기 계획 (3-6개월)
1. **X-Ray 통합**: 분산 추적 본격 활용
2. **로그 분석 자동화**: CloudWatch Insights 쿼리 자동화
3. **예측 알람**: 머신러닝 기반 이상 탐지

### 장기 계획 (6-12개월)
1. **멀티 리전 모니터링**: 글로벌 서비스 모니터링
2. **통합 관제 시스템**: 외부 모니터링 도구 연동
3. **자동 복구**: 알람 기반 자동 복구 시스템

---

## 📞 지원 및 문의

### 기술 지원
- **DevOps 팀**: devops@company.com
- **개발 팀**: dev@company.com
- **인프라 팀**: infra@company.com

### 문서 및 리소스
- **모니터링 가이드**: `docs/MONITORING.md`
- **설정 가이드**: `docs/CLOUDWATCH_SETUP.md`
- **아키텍처 문서**: `docs/ARCHITECTURE.md`
- **AWS 공식 문서**: [CloudWatch 사용자 가이드](https://docs.aws.amazon.com/cloudwatch/)

### 이슈 리포팅
- **GitHub Issues**: 프로젝트 저장소 이슈 트래커 활용
- **긴급 상황**: 24/7 온콜 시스템 (별도 안내)

---

**문서 버전**: v1.0  
**최종 업데이트**: 2024년 1월  
**작성자**: DevOps Team