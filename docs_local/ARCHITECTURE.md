# Popcorn MSA 인프라 아키텍처

## 전체 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Gateway                          │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                   Public Subnets                                │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │  ALB (AZ-2a)    │              │  ALB (AZ-2c)    │           │
│  └─────────────────┘              └─────────────────┘           │
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                  Private Subnets                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                ECS Fargate Services                         ││
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           ││
│  │  │ API Gateway │ │ User Service│ │Store Service│    ...    ││
│  │  └─────────────┘ └─────────────┘ └─────────────┘           ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    EC2 Kafka                                ││
│  │  ┌─────────────┐                                            ││
│  │  │ Kafka Node  │                                            ││
│  │  └─────────────┘                                            ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────┬───────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────────┐
│                    Data Subnets                                 │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │ RDS PostgreSQL  │              │  ElastiCache    │           │
│  │    (AZ-2a)      │              │   (AZ-2a)       │           │
│  └─────────────────┘              └─────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## 네트워크 아키텍처

### VPC 구성
- **CIDR**: 10.0.0.0/16
- **가용 영역**: ap-northeast-2a, ap-northeast-2c
- **서브넷 구성**:
  - Public Subnets: ALB 배치 (Multi-AZ)
  - Private Subnets: ECS, Kafka 배치 (Single-AZ for dev)
  - Data Subnets: RDS, ElastiCache 배치 (Multi-AZ for subnet group)

### 서브넷 세부 구성

| 서브넷 타입 | CIDR | AZ | 용도 |
|-------------|------|----|----- |
| Public-2a | 10.0.1.0/24 | ap-northeast-2a | ALB, NAT Gateway |
| Public-2c | 10.0.2.0/24 | ap-northeast-2c | ALB (Multi-AZ) |
| Private-2a | 10.0.11.0/24 | ap-northeast-2a | ECS, Kafka |
| Data-2a | 10.0.21.0/24 | ap-northeast-2a | RDS, ElastiCache |
| Data-2c | 10.0.22.0/24 | ap-northeast-2c | RDS Subnet Group |

## 컴퓨팅 아키텍처

### ECS Fargate 클러스터
```
ECS Cluster: goorm-popcorn-dev-cluster
├── API Gateway Service
│   ├── Task Definition: 512 CPU, 1024 MB
│   ├── Desired Count: 1
│   └── Auto Scaling: CPU/Memory 기반
├── User Service
│   ├── Task Definition: 256 CPU, 512 MB
│   ├── Desired Count: 1
│   └── Auto Scaling: CPU/Memory 기반
├── Store Service
│   ├── Task Definition: 256 CPU, 512 MB
│   ├── Desired Count: 1
│   └── Auto Scaling: CPU/Memory 기반
├── Order Service
│   ├── Task Definition: 256 CPU, 512 MB
│   ├── Desired Count: 1
│   └── Auto Scaling: CPU/Memory 기반
├── Payment Service
│   ├── Task Definition: 256 CPU, 512 MB
│   ├── Desired Count: 1
│   └── Auto Scaling: CPU/Memory 기반
├── Check-in Service
│   ├── Task Definition: 256 CPU, 512 MB
│   ├── Desired Count: 1
│   └── Auto Scaling: CPU/Memory 기반
└── Order Query Service
    ├── Task Definition: 256 CPU, 512 MB
    ├── Desired Count: 1
    └── Auto Scaling: CPU/Memory 기반
```

### EC2 Kafka 클러스터
- **인스턴스 타입**: t3.small
- **노드 수**: 1 (dev), 3 (prod)
- **모드**: KRaft (Zookeeper 불필요)
- **스토리지**: 
  - Root: 8GB GP3
  - Data: 20GB GP3

## 데이터 아키텍처

### RDS PostgreSQL
- **엔진**: PostgreSQL 18.1
- **인스턴스**: db.t4g.micro (ARM 기반)
- **스토리지**: 20GB GP3
- **백업**: 1일 보존 (dev)
- **Multi-AZ**: 비활성화 (dev)
- **암호화**: 활성화

### ElastiCache (Valkey)
- **엔진**: Valkey 8.0
- **노드 타입**: cache.t4g.micro
- **클러스터 수**: 1 (dev)
- **자동 장애조치**: 비활성화 (dev)
- **암호화**: 저장 시 암호화 활성화

## 로드 밸런싱 아키텍처

### Application Load Balancer
```
ALB: goorm-popcorn-alb-dev
├── Listener: HTTP (80) → HTTPS (443) 리다이렉트
├── Listener: HTTPS (443)
│   ├── SSL Certificate: *.goormpopcorn.shop
│   └── Target Group: goorm-popcorn-gateway-dev
│       └── Target: API Gateway Service (Port 8080)
└── Health Check: /health
```

### 서비스 디스커버리
```
CloudMap Namespace: goormpopcorn.local
├── api-gateway.goormpopcorn.local
├── user-service.goormpopcorn.local
├── store-service.goormpopcorn.local
├── order-service.goormpopcorn.local
├── payment-service.goormpopcorn.local
├── checkin-service.goormpopcorn.local
└── order-query.goormpopcorn.local
```

## 보안 아키텍처

### Security Groups

#### ALB Security Group
```
Inbound Rules:
- HTTP (80): 0.0.0.0/0
- HTTPS (443): 0.0.0.0/0

Outbound Rules:
- Port 8080: ECS Security Group
```

#### ECS Security Group
```
Inbound Rules:
- Port 8080: ALB Security Group
- Port 8080: ECS Security Group (서비스 간 통신)

Outbound Rules:
- HTTPS (443): 0.0.0.0/0 (ECR, Secrets Manager)
- Port 5432: DB Security Group
- Port 6379: Cache Security Group
- Port 9092, 9094: Kafka Security Group
```

#### Database Security Group
```
Inbound Rules:
- Port 5432: ECS Security Group

Outbound Rules: None
```

#### Cache Security Group
```
Inbound Rules:
- Port 6379: ECS Security Group

Outbound Rules: None
```

#### Kafka Security Group
```
Inbound Rules:
- Port 9092, 9094: ECS Security Group

Outbound Rules: None
```

## 모니터링 아키텍처

### CloudWatch 구성
```
CloudWatch
├── Log Groups
│   ├── /aws/ecs/goorm-popcorn-dev/api-gateway
│   ├── /aws/ecs/goorm-popcorn-dev/user-service
│   ├── /aws/ecs/goorm-popcorn-dev/store-service
│   ├── /aws/ecs/goorm-popcorn-dev/order-service
│   ├── /aws/ecs/goorm-popcorn-dev/payment-service
│   ├── /aws/ecs/goorm-popcorn-dev/checkin-service
│   ├── /aws/ecs/goorm-popcorn-dev/order-query
│   ├── /aws/ec2/kafka-dev
│   └── /aws/ecs/goorm-popcorn-dev/exec
├── Metrics
│   ├── Container Insights (ECS)
│   ├── RDS Performance Insights
│   └── Custom Application Metrics
├── Alarms
│   ├── ECS CPU/Memory 사용률
│   ├── ALB 응답시간/에러율
│   ├── RDS 성능 메트릭
│   └── ElastiCache 성능 메트릭
└── Dashboards
    └── goorm-popcorn-dev-overview
```

### 추가 모니터링 (선택적)
- **VPC Flow Logs**: 네트워크 트래픽 분석
- **X-Ray**: 분산 추적
- **ALB Access Logs**: S3에 저장

## 배포 아키텍처

### CI/CD 파이프라인
```
GitHub Actions
├── Feature Branch CI
│   ├── 코드 품질 검사
│   ├── 단위 테스트
│   └── 보안 스캔
└── Main Branch CD
    ├── Docker 이미지 빌드
    ├── ECR 푸시
    ├── ECS 서비스 업데이트
    └── 배포 검증
```

### ECR 리포지토리
```
ECR Repositories
├── goorm-popcorn-api-gateway
├── goorm-popcorn-user
├── goorm-popcorn-store
├── goorm-popcorn-order
├── goorm-popcorn-payment
├── goorm-popcorn-checkin
└── goorm-popcorn-order-query
```

## 환경별 차이점

### 개발 환경 (dev)
- **목적**: 개발 및 테스트
- **가용성**: Single-AZ (비용 절약)
- **인스턴스**: 최소 사양
- **백업**: 최소 보존 기간
- **모니터링**: 기본 설정

### 프로덕션 환경 (prod)
- **목적**: 실제 서비스 운영
- **가용성**: Multi-AZ (고가용성)
- **인스턴스**: 성능 최적화 사양
- **백업**: 장기 보존
- **모니터링**: 전체 모니터링 활성화

## 확장성 고려사항

### 수평 확장
- **ECS Auto Scaling**: CPU/Memory 기반 자동 스케일링
- **RDS Read Replica**: 읽기 성능 향상
- **ElastiCache Cluster**: 캐시 성능 향상

### 수직 확장
- **인스턴스 타입 업그레이드**: 더 큰 인스턴스로 변경
- **스토리지 확장**: GP3 IOPS/처리량 증가

## 재해 복구

### 백업 전략
- **RDS**: 자동 백업 + 수동 스냅샷
- **ElastiCache**: 자동 스냅샷
- **ECS**: 컨테이너 이미지 ECR 저장
- **Kafka**: 데이터 복제 (Multi-node)

### 복구 절차
1. **데이터베이스 복구**: RDS 스냅샷에서 복원
2. **캐시 복구**: ElastiCache 스냅샷에서 복원
3. **서비스 복구**: ECS 서비스 재시작
4. **네트워크 복구**: VPC/서브넷 재생성

## 성능 최적화

### 네트워크 최적화
- **VPC Endpoints**: S3, ECR 접근 최적화
- **CloudFront**: 정적 콘텐츠 CDN
- **Route 53**: DNS 최적화

### 애플리케이션 최적화
- **Connection Pooling**: 데이터베이스 연결 최적화
- **캐시 전략**: Redis 캐시 활용
- **비동기 처리**: Kafka 메시지 큐 활용

## 비용 최적화

### 리소스 최적화
- **Spot 인스턴스**: ECS Fargate Spot 활용
- **Reserved Instances**: RDS 예약 인스턴스
- **Right Sizing**: 적절한 인스턴스 크기 선택

### 운영 최적화
- **자동 스케일링**: 필요시에만 리소스 확장
- **스케줄링**: 개발 환경 자동 시작/중지
- **모니터링**: 불필요한 리소스 식별 및 제거