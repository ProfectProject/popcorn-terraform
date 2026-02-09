# ECS Task Definition 관리 가이드

**날짜**: 2024-01-26  
**프로젝트**: Goorm Popcorn Infrastructure  

---

## 관리 방식 비교

### 1. 현재 방식: Terraform 내 관리
```
❌ 문제점:
- 애플리케이션 변경 시마다 인프라 배포 필요
- 개발자가 직접 수정하기 어려움
- 배포 속도 저하
- 인프라와 애플리케이션 결합도 높음
```

### 2. 권장 방식: 하이브리드 관리
```
✅ 장점:
- 인프라: ECS Cluster, Service 기본 구조
- 애플리케이션: Task Definition 상세 구성
- 빠른 배포와 안정적인 인프라 관리 병행
```

---

## 권장 아키텍처

### Phase 1: 현재 → 전환 (단계적 적용)

```
📁 popcorn-terraform-feature/
├── modules/ecs/
│   ├── main.tf (기본 ECS 구조만 관리)
│   └── task-definitions/ (임시: 기본 Task Definition)
│
📁 각 애플리케이션 레포/
├── .aws/
│   └── task-definition.json (상세 구성)
├── .github/workflows/
│   └── deploy.yml (배포 파이프라인)
└── src/ (애플리케이션 코드)
```

### Phase 2: 최종 목표

```
📁 Infrastructure Repository (Terraform)
├── ECS Cluster, Service, ALB 관리
└── 기본 보안, 네트워킹 설정

📁 Application Repository (각 서비스별)
├── Task Definition 완전 관리
├── 배포 파이프라인
└── 애플리케이션별 설정
```

---

## 서비스별 Task Definition

### 공통 설정

```json
{
  "family": "goorm-popcorn-{service-name}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "executionRoleArn": "arn:aws:iam::375896310755:role/goorm-popcorn-dev-ecs-task-execution-role",
  "taskRoleArn": "arn:aws:iam::375896310755:role/goorm-popcorn-dev-ecs-task-role"
}
```

### 환경별 리소스 할당

| 서비스 | Dev CPU | Dev Memory | Prod CPU | Prod Memory | 특징 |
|--------|---------|------------|----------|-------------|------|
| api-gateway | 512 | 1024 | 1024 | 2048 | 높은 트래픽 처리 |
| user-service | 256 | 512 | 512 | 1024 | 표준 CRUD |
| store-service | 256 | 512 | 512 | 1024 | 표준 CRUD |
| order-service | 512 | 1024 | 1024 | 2048 | 복잡한 비즈니스 로직 |
| payment-service | 512 | 1024 | 1024 | 2048 | 높은 보안, 안정성 |
| qr-service | 256 | 512 | 256 | 512 | 경량 서비스 |
| order-query | 256 | 512 | 512 | 1024 | 읽기 전용 최적화 |

---

## 전환 계획

### Step 1: Task Definition 파일 생성 (현재)
각 서비스별 Task Definition JSON 파일 생성

### Step 2: Terraform 단순화 (다음 단계)
Terraform에서 Task Definition 제거, 서비스만 관리

### Step 3: CI/CD 파이프라인 구축 (최종)
애플리케이션 레포에서 직접 ECS 배포

---

## 즉시 적용 가능한 개선사항

### 1. Task Definition 템플릿 생성
각 서비스별 최적화된 Task Definition 제공

### 2. 환경 변수 표준화
공통 환경 변수와 서비스별 환경 변수 분리

### 3. 헬스체크 최적화
서비스별 특성에 맞는 헬스체크 설정

### 4. 로깅 및 모니터링 강화
서비스별 로그 레벨과 메트릭 설정

---

## 생성된 Task Definition 파일들

### 📁 파일 구조

```
popcorn-terraform-feature/
├── task-definitions/
│   ├── api-gateway.json      # API Gateway (512 CPU, 1024 Memory)
│   ├── user-service.json     # User Service (256 CPU, 512 Memory)
│   ├── store-service.json    # Store Service (256 CPU, 512 Memory)
│   ├── order-service.json    # Order Service (512 CPU, 1024 Memory)
│   ├── payment-service.json  # Payment Service (512 CPU, 1024 Memory)
│   ├── qr-service.json       # QR Service (256 CPU, 512 Memory)
│   └── order-query.json      # Order Query (256 CPU, 512 Memory)
├── scripts/
│   └── deploy-task-definitions.sh  # 배포 스크립트
└── docs/
    └── ecs-task-definition-management.md  # 이 문서
```

### 🔧 서비스별 특징

#### 1. API Gateway
- **리소스**: 512 CPU, 1024 Memory
- **특징**: 모든 외부 요청의 진입점, 높은 처리량 필요
- **환경변수**: 모든 백엔드 서비스 URL 포함
- **헬스체크**: 90초 시작 대기 시간

#### 2. User Service
- **리소스**: 256 CPU, 512 Memory
- **특징**: 사용자 인증/인가, JWT 토큰 관리
- **데이터베이스**: PostgreSQL 연결
- **캐시**: Redis 세션 관리

#### 3. Store Service
- **리소스**: 256 CPU, 512 Memory
- **특징**: 매장 정보 관리, 파일 업로드 지원
- **스토리지**: S3 연동, 임시 볼륨 마운트
- **데이터베이스**: PostgreSQL 연결

#### 4. Order Service
- **리소스**: 512 CPU, 1024 Memory
- **특징**: 복잡한 주문 로직, Saga 패턴
- **메시징**: Kafka Producer/Consumer
- **타임아웃**: 주문 30분, Saga 5분

#### 5. Payment Service
- **리소스**: 512 CPU, 1024 Memory
- **특징**: 높은 보안 수준, 결제 게이트웨이 연동
- **보안**: 암호화 키, TossPayments 연동
- **로깅**: 보안을 위해 INFO 레벨

#### 6. QR Service
- **리소스**: 256 CPU, 512 Memory
- **특징**: 경량 서비스, QR 코드 생성
- **스토리지**: S3 QR 코드 저장
- **캐시**: Redis 기반 QR 코드 캐싱

#### 7. Order Query Service
- **리소스**: 256 CPU, 512 Memory
- **특징**: 읽기 전용 최적화, CQRS 패턴
- **캐시**: Redis 쿼리 결과 캐싱
- **페이징**: 기본 20개, 최대 100개

---

## 사용 방법

### 1. 개별 서비스 배포

```bash
# API Gateway 배포
./scripts/deploy-task-definitions.sh api-gateway dev latest

# User Service 배포 (특정 태그)
./scripts/deploy-task-definitions.sh user-service dev feature-auth-abc123
```

### 2. 전체 서비스 배포

```bash
# 모든 서비스 배포
./scripts/deploy-task-definitions.sh all dev latest
```

### 3. 프로덕션 배포

```bash
# 프로덕션 환경 배포
./scripts/deploy-task-definitions.sh api-gateway prod v1.2.3
```

---

## 환경 변수 자동 치환

배포 스크립트는 다음 변수들을 자동으로 치환합니다:

```bash
${DB_HOST}                    # RDS 엔드포인트
${DB_PORT}                    # 데이터베이스 포트 (5432)
${DB_NAME}                    # 데이터베이스 이름
${DB_SECRET_ARN}              # RDS 비밀번호 Secret ARN
${REDIS_PRIMARY_ENDPOINT}     # ElastiCache 엔드포인트
${KAFKA_BOOTSTRAP_SERVERS}    # Kafka 브로커 주소
```

---

## CI/CD 통합 예시

### GitHub Actions 워크플로우

```yaml
name: Deploy ECS Service

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2
      
      - name: Build and push Docker image
        run: |
          # Docker 빌드 및 ECR 푸시 로직
          
      - name: Deploy Task Definition
        run: |
          # Task Definition 배포
          ./scripts/deploy-task-definitions.sh user-service dev ${{ github.sha }}
```

---

## 모니터링 및 로깅

### CloudWatch 로그 그룹

각 서비스별로 별도의 로그 그룹이 생성됩니다:

```
/aws/ecs/goorm-popcorn-dev/api-gateway
/aws/ecs/goorm-popcorn-dev/user-service
/aws/ecs/goorm-popcorn-dev/store-service
/aws/ecs/goorm-popcorn-dev/order-service
/aws/ecs/goorm-popcorn-dev/payment-service
/aws/ecs/goorm-popcorn-dev/qr-service
/aws/ecs/goorm-popcorn-dev/order-query
```

### 헬스체크 설정

모든 서비스는 Spring Boot Actuator의 `/actuator/health` 엔드포인트를 사용합니다:

- **간격**: 30초
- **타임아웃**: 5-10초 (서비스별 차이)
- **재시도**: 3-5회
- **시작 대기**: 45-120초 (서비스별 차이)

---

## 보안 고려사항

### 1. Secrets Manager 사용
- 데이터베이스 비밀번호
- 결제 게이트웨이 API 키
- 암호화 키

### 2. IAM 역할 분리
- Task Execution Role: ECR, CloudWatch 접근
- Task Role: AWS 서비스 접근 (S3, Secrets Manager 등)

### 3. 네트워크 보안
- Private 서브넷에서 실행
- Security Group으로 트래픽 제어
- ALB를 통한 외부 접근만 허용

---

## 다음 단계

### Phase 1: 현재 구조 개선 (즉시 적용 가능)
1. ✅ Task Definition 파일 생성 완료
2. ✅ 배포 스크립트 생성 완료
3. ⏳ Terraform에서 Task Definition 제거
4. ⏳ CI/CD 파이프라인 구축

### Phase 2: 애플리케이션 레포 이관 (중장기)
1. 각 서비스 레포에 Task Definition 이관
2. 서비스별 독립적인 배포 파이프라인
3. 개발팀 자율적 배포 환경 구축

---

## 문제 해결

### 일반적인 문제들

1. **Task Definition 등록 실패**
   ```bash
   # IAM 권한 확인
   aws sts get-caller-identity
   
   # Task Definition 구문 검증
   aws ecs register-task-definition --generate-cli-skeleton
   ```

2. **서비스 업데이트 실패**
   ```bash
   # 서비스 상태 확인
   aws ecs describe-services --cluster goorm-popcorn-dev-cluster --services goorm-popcorn-dev-api-gateway
   
   # 배포 상태 확인
   aws ecs describe-services --cluster goorm-popcorn-dev-cluster --services goorm-popcorn-dev-api-gateway --query 'services[0].deployments'
   ```

3. **환경 변수 치환 오류**
   ```bash
   # Terraform 출력 확인
   terraform -chdir="../envs/dev" output
   
   # 수동 치환 테스트
   sed 's/${DB_HOST}/actual-db-host/g' task-definitions/user-service.json
   ```

---

**결론**: 현재 생성된 Task Definition들은 각 서비스의 특성을 반영하여 최적화되었으며, 단계적으로 애플리케이션 레포로 이관하여 더 효율적인 관리가 가능합니다.