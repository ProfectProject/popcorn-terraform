# Task 4.1 - Prod 환경 디렉터리 구조 확인

## 작업 정보

- **작업 일시**: 2025-02-09
- **작업자**: Kiro AI Agent
- **작업 내용**: Prod 환경 디렉터리 구조 확인 및 기존 파일 백업

## 작업 개요

Prod 환경(`envs/prod/`) 디렉터리의 기존 파일들을 확인하고, 향후 리팩토링 작업을 위해 백업 파일을 생성했습니다.

## 디렉터리 구조

### 기존 파일 목록

```
envs/prod/
├── .terraform/              # Terraform 초기화 디렉터리
├── backend.tf               # S3 백엔드 설정
├── main.tf                  # 메인 인프라 구성
├── rds.tf                   # RDS PostgreSQL 구성
├── terraform.tfvars         # 환경별 변수 값
├── terraform.tfvars.example # 변수 예제 파일
├── variables.tf             # 변수 정의
└── versions.tf              # Terraform 버전 설정
```

### 백업 파일 생성

다음 파일들의 백업을 생성했습니다 (`.back` 확장자):

```
envs/prod/
├── backend.tf.back          # 240 bytes
├── main.tf.back             # 5,278 bytes
├── rds.tf.back              # 9,271 bytes
├── terraform.tfvars.back    # 3,153 bytes
└── variables.tf.back        # 2,899 bytes
```

## 기존 파일 분석

### 1. backend.tf
- **목적**: Terraform 상태 파일 원격 저장
- **구성**:
  - S3 버킷: `goorm-popcorn-tfstate`
  - 상태 파일 경로: `prod/terraform.tfstate`
  - DynamoDB 잠금 테이블: `goorm-popcorn-tfstate-lock`
  - 암호화: 활성화

### 2. main.tf
- **목적**: Prod 환경 메인 인프라 구성
- **주요 모듈**:
  - VPC 모듈 (Multi-AZ)
  - Security Groups 모듈
  - ALB 모듈
  - ElastiCache 모듈 (Valkey, Primary + Replica)
  - IAM 모듈
  - EKS 모듈
- **Route53 레코드**:
  - goormpopcorn.shop (메인 도메인)
  - api.goormpopcorn.shop
  - kafka.goormpopcorn.shop
  - argocd.goormpopcorn.shop
  - grafana.goormpopcorn.shop
- **원격 상태 참조**:
  - Global Route53 & ACM
  - Global ECR

### 3. rds.tf
- **목적**: RDS PostgreSQL 구성 (Multi-AZ)
- **주요 구성**:
  - 인스턴스 클래스: `db.t4g.micro` (최저 스펙)
  - Multi-AZ: 활성화 (고가용성)
  - 백업 보존: 7일
  - Enhanced Monitoring: 활성화 (1분 간격)
  - Performance Insights: 활성화 (7일 보존)
  - Deletion Protection: 활성화
  - CloudWatch 알람: CPU, 연결 수, 스토리지, 레이턴시
- **보안**:
  - Secrets Manager를 통한 비밀번호 관리
  - VPC 내부 접근만 허용
  - 전송 중/저장 시 암호화

### 4. terraform.tfvars
- **목적**: Prod 환경 변수 값 정의
- **주요 설정**:
  - **Multi-AZ 구성**: ap-northeast-2a, ap-northeast-2c
  - **VPC CIDR**: 10.0.0.0/16
  - **서브넷**:
    - Public: 10.0.1.0/24, 10.0.2.0/24
    - Private: 10.0.11.0/24, 10.0.12.0/24
    - Data: 10.0.21.0/24, 10.0.22.0/24
  - **NAT Gateway**: Multi-AZ (고가용성)
  - **ElastiCache**: cache.t4g.small, 2개 노드, 자동 장애조치
  - **EKS**: t3.medium~large, 3-20 노드, ON_DEMAND
  - **ECR 리포지토리**: 8개 서비스 매핑

### 5. variables.tf
- **목적**: 변수 정의 및 타입 지정
- **주요 변수 그룹**:
  - 네트워크 변수 (VPC, 서브넷)
  - 보안 그룹 변수
  - ALB 변수
  - ElastiCache 변수
  - IAM 변수
  - EKS 변수
  - ECR 변수
  - RDS 변수
  - 공통 태그

## 환경 특성 분석

### Prod 환경 특징

1. **고가용성 (High Availability)**
   - Multi-AZ 구성 (2개 AZ)
   - RDS Multi-AZ 자동 장애조치
   - ElastiCache Primary + Replica
   - Multi-AZ NAT Gateway

2. **보안 강화**
   - Deletion Protection 활성화
   - 전송 중/저장 시 암호화
   - Secrets Manager 통합
   - Enhanced Monitoring

3. **모니터링 강화**
   - Performance Insights 활성화
   - CloudWatch 알람 (CPU, 연결, 스토리지, 레이턴시)
   - SNS 알림 통합
   - 7일 로그 보존

4. **비용 최적화**
   - 최저 스펙 인스턴스 (db.t4g.micro)
   - 자동 스토리지 확장 (20GB → 200GB)
   - 필요 시 Read Replica 추가 가능

## Dev vs Prod 환경 비교

| 항목 | Dev 환경 | Prod 환경 |
|------|----------|-----------|
| **AZ 구성** | 단일 AZ (2a) | Multi-AZ (2a, 2c) |
| **NAT Gateway** | 단일 (비용 절감) | Multi-AZ (고가용성) |
| **RDS** | 단일 인스턴스 | Multi-AZ, 자동 장애조치 |
| **RDS 백업** | 1일 보존 | 7일 보존 |
| **ElastiCache** | 단일 노드 | Primary + Replica |
| **EKS 노드** | 2-5개 | 3-20개 |
| **모니터링** | 기본 | Enhanced + Performance Insights |
| **보안** | 기본 | Deletion Protection, 강화된 암호화 |

## 검증 결과

### ✅ 확인 완료 사항

1. **디렉터리 존재 확인**: `envs/prod/` 디렉터리 존재
2. **기존 파일 확인**: 7개 파일 확인 (Terraform 설정 파일)
3. **백업 파일 생성**: 5개 주요 파일 백업 완료
4. **파일 구조 분석**: 모든 파일의 목적과 내용 파악
5. **환경 특성 파악**: Prod 환경의 고가용성 및 보안 설정 확인

### 📋 백업 파일 상세

| 파일명 | 크기 | 백업 파일 | 상태 |
|--------|------|-----------|------|
| backend.tf | 240 bytes | backend.tf.back | ✅ |
| main.tf | 5,278 bytes | main.tf.back | ✅ |
| rds.tf | 9,271 bytes | rds.tf.back | ✅ |
| terraform.tfvars | 3,153 bytes | terraform.tfvars.back | ✅ |
| variables.tf | 2,899 bytes | variables.tf.back | ✅ |

## 다음 단계

Task 4.2에서 다음 작업을 진행할 예정입니다:

1. **Prod 환경 main.tf 개선**
   - 모듈 호출 최적화
   - 주석 추가 및 코드 정리
   - 환경별 설정 명확화

2. **추가 모듈 통합**
   - Monitoring 모듈 추가
   - 필요 시 추가 보안 설정

3. **Route53 레코드 검증**
   - 서브도메인 설정 확인
   - ALB 연결 검증

## 참고 사항

- 모든 백업 파일은 `.back` 확장자로 저장되어 있습니다
- 원본 파일은 그대로 유지되어 있습니다
- 백업 파일은 Git에 커밋하지 않습니다 (`.gitignore` 확인 필요)
- 향후 리팩토링 시 백업 파일을 참조할 수 있습니다

## 작업 완료

Task 4.1 작업이 성공적으로 완료되었습니다.

- ✅ Prod 환경 디렉터리 구조 확인
- ✅ 기존 파일 목록 확인
- ✅ 백업 파일 생성 (5개 파일)
- ✅ 디렉터리 구조 문서화
- ✅ 환경 특성 분석 완료
