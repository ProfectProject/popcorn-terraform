# 태스크 2.2-2.7: Security Groups 구현

## 완료 일시
2025-02-08

## 태스크 내용

### 2.2 Public ALB Security Group 구현
- aws_security_group 리소스 정의
- 인터넷(0.0.0.0/0)에서 80, 443 포트 허용 규칙
- Requirements: 7.1, 7.6

### 2.3 Management ALB Security Group 구현
- aws_security_group 리소스 정의
- 화이트리스트 IP에서만 80, 443 포트 허용 규칙
- Requirements: 7.2, 7.7, 6.8

### 2.4 EKS Node Security Group 구현
- aws_security_group 리소스 정의
- ALB에서 모든 포트 허용 규칙
- Requirements: 7.3, 7.8

### 2.5 RDS Security Group 구현
- aws_security_group 리소스 정의
- EKS Node에서 5432 포트 허용 규칙
- Requirements: 7.4, 7.9

### 2.6 ElastiCache Security Group 구현
- aws_security_group 리소스 정의
- EKS Node에서 6379 포트 허용 규칙
- Requirements: 7.5, 7.10

### 2.7 Security Groups 출력 값 정의
- public_alb_sg_id, management_alb_sg_id 출력
- rds_sg_id, elasticache_sg_id 출력
- Requirements: 7.1, 7.2, 7.4, 7.5

## 실행 결과

### ✅ 완료된 작업

모든 보안 그룹이 `modules/security-groups/main.tf`에 구현되어 있습니다.

#### 1. Public ALB Security Group ✅

**리소스**: `aws_security_group.public_alb`
- 이름: `popcorn-{environment}-public-alb-sg`
- 설명: "Public ALB 보안 그룹 - 외부 사용자 접근용 (Frontend)"

**Ingress 규칙**:
- HTTP (80): 0.0.0.0/0 → Public ALB
- HTTPS (443): 0.0.0.0/0 → Public ALB

**Egress 규칙**:
- 모든 포트 (0-65535): Public ALB → 0.0.0.0/0 (EKS Node로)

#### 2. Management ALB Security Group ✅

**리소스**: `aws_security_group.management_alb`
- 이름: `popcorn-{environment}-management-alb-sg`
- 설명: "Management ALB 보안 그룹 - 관리 도구 접근용 (Kafka, ArgoCD, Grafana)"

**Ingress 규칙**:
- HTTP (80): 화이트리스트 IP → Management ALB
- HTTPS (443): 화이트리스트 IP → Management ALB

**Egress 규칙**:
- 모든 포트 (0-65535): Management ALB → 0.0.0.0/0 (EKS Node로)

#### 3. EKS Node Security Group 규칙 ✅

**리소스**: `aws_security_group_rule.eks_node_ingress_from_*`
- EKS 모듈에서 생성된 보안 그룹에 규칙 추가
- 조건부 생성: `eks_node_security_group_id`가 제공된 경우에만

**Ingress 규칙**:
- 모든 포트 (0-65535): Public ALB → EKS Node
- 모든 포트 (0-65535): Management ALB → EKS Node

#### 4. RDS Security Group ✅

**리소스**: `aws_security_group.rds`
- 이름: `popcorn-{environment}-rds-sg`
- 설명: "RDS PostgreSQL 보안 그룹 - EKS Node에서만 접근 허용"

**Ingress 규칙**:
- PostgreSQL (5432): EKS Node → RDS

**Egress 규칙**:
- 없음 (기본적으로 아웃바운드 트래픽 불필요)

#### 5. ElastiCache Security Group ✅

**리소스**: `aws_security_group.elasticache`
- 이름: `popcorn-{environment}-elasticache-sg`
- 설명: "ElastiCache Valkey 보안 그룹 - EKS Node에서만 접근 허용"

**Ingress 규칙**:
- Redis/Valkey (6379): EKS Node → ElastiCache

**Egress 규칙**:
- 없음 (기본적으로 아웃바운드 트래픽 불필요)

#### 6. 출력 값 ✅

**modules/security-groups/outputs.tf**:
- `public_alb_sg_id`: Public ALB 보안 그룹 ID
- `management_alb_sg_id`: Management ALB 보안 그룹 ID
- `rds_sg_id`: RDS 보안 그룹 ID
- `elasticache_sg_id`: ElastiCache 보안 그룹 ID
- 추가: 각 보안 그룹의 이름도 출력

### 🎯 요구사항 충족

- ✅ Requirements 7.1: Public ALB 보안 그룹 생성
- ✅ Requirements 7.2: Management ALB 보안 그룹 생성
- ✅ Requirements 7.3: EKS Node 보안 그룹 규칙 생성
- ✅ Requirements 7.4: RDS 보안 그룹 생성
- ✅ Requirements 7.5: ElastiCache 보안 그룹 생성
- ✅ Requirements 7.6: Public ALB 인터넷 접근 허용
- ✅ Requirements 7.7: Management ALB 화이트리스트 IP 접근 허용
- ✅ Requirements 7.8: EKS Node ALB 접근 허용
- ✅ Requirements 7.9: RDS EKS Node 접근 허용
- ✅ Requirements 7.10: ElastiCache EKS Node 접근 허용
- ✅ Requirements 6.8: Management ALB IP 화이트리스트 적용

### 📊 보안 원칙 준수

1. **최소 권한 원칙**
   - 각 보안 그룹은 필요한 최소한의 포트만 허용
   - 소스/대상을 명확히 지정

2. **계층별 분리**
   - Public ALB: 인터넷 접근
   - Management ALB: 화이트리스트 IP만 접근
   - RDS/ElastiCache: EKS Node에서만 접근

3. **명시적 규칙**
   - 모든 규칙에 설명(description) 포함
   - 한국어로 명확한 설명 작성

### 📝 코드 품질

- ✅ 한국어 주석 및 설명
- ✅ 일관된 명명 규칙
- ✅ 태그 관리 (local.common_tags 사용)
- ✅ 조건부 리소스 생성 (count 사용)

## 검증된 파일

```
modules/security-groups/
├── main.tf (검증 완료)
└── outputs.tf (검증 완료)
```

## 다음 단계

태스크 2.8: Security Groups 모듈 단위 테스트
