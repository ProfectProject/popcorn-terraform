# Task 4.5: Prod 환경 backend.tf 작성

## 작업 일시
2025-02-05

## 작업 내용

### 1. Prod 환경 backend.tf 파일 생성
- **파일 경로**: `popcorn-terraform-feature/envs/prod/backend.tf`
- **참조 파일**: `popcorn-terraform-feature/envs/dev/backend.tf`

### 2. 설정 내용

#### S3 백엔드 설정
- **버킷 이름**: `popcorn-terraform-state`
- **상태 파일 키**: `prod/terraform.tfstate`
- **리전**: `ap-northeast-2`
- **암호화**: 활성화 (`encrypt = true`)

#### DynamoDB 잠금 테이블
- **테이블 이름**: `popcorn-terraform-state-lock`
- **목적**: Terraform 상태 파일 동시 수정 방지

### 3. Dev 환경과의 차이점

| 항목 | Dev 환경 | Prod 환경 |
|------|----------|-----------|
| S3 버킷 | `goorm-popcorn-tfstate` | `popcorn-terraform-state` |
| 상태 파일 키 | `dev/terraform.tfstate` | `prod/terraform.tfstate` |
| DynamoDB 테이블 | `goorm-popcorn-tfstate-lock` | `popcorn-terraform-state-lock` |

### 4. 검증 결과

#### 코드 포맷 검증
```bash
terraform fmt -check backend.tf
```
- **결과**: ✅ 통과 (Exit Code: 0)
- **설명**: 코드 포맷이 Terraform 표준을 준수함

#### 구문 검증
- **backend.tf 파일 자체**: ✅ 문제 없음
- **전체 Terraform 설정**: EKS 모듈에 일부 오류 있음 (별도 수정 필요)

### 5. 파일 내용

```hcl
terraform {
  backend "s3" {
    bucket         = "popcorn-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "popcorn-terraform-state-lock"
    encrypt        = true
  }
}
```

## 요구사항 충족 확인

### Requirements 12.1: Terraform 상태를 S3 버킷에 저장
- ✅ S3 버킷 `popcorn-terraform-state` 설정 완료
- ✅ 리전 `ap-northeast-2` 설정 완료

### Requirements 12.2: DynamoDB 테이블을 사용하여 상태 잠금 구현
- ✅ DynamoDB 테이블 `popcorn-terraform-state-lock` 설정 완료

### Requirements 12.4: S3 버킷 암호화 활성화
- ✅ `encrypt = true` 설정 완료

### Requirements 12.5: 환경별로 별도의 상태 파일 관리
- ✅ Prod 환경 상태 파일 키: `prod/terraform.tfstate`
- ✅ Dev 환경과 분리된 상태 파일 관리

## 보안 고려사항

### 1. 암호화
- **전송 중 암호화**: S3 HTTPS 엔드포인트 사용
- **저장 시 암호화**: `encrypt = true` 설정으로 AES-256 암호화 활성화

### 2. 상태 잠금
- DynamoDB 테이블을 통한 동시 수정 방지
- 여러 사용자가 동시에 `terraform apply` 실행 시 충돌 방지

### 3. 버전 관리
- S3 버킷 버전 관리 활성화 권장 (별도 설정 필요)
- 상태 파일 변경 이력 추적 가능

## 다음 단계

### Task 4.6: Prod 환경 outputs.tf 작성
- VPC ID, 서브넷 ID 출력
- EKS 클러스터 엔드포인트 출력
- RDS 엔드포인트 출력
- ElastiCache 엔드포인트 출력
- ALB DNS 이름 출력

## 참고사항

### S3 버킷 사전 요구사항
backend.tf를 사용하기 전에 다음 리소스가 사전에 생성되어 있어야 합니다:

1. **S3 버킷**: `popcorn-terraform-state`
   - 버전 관리 활성화
   - 암호화 활성화
   - 퍼블릭 액세스 차단

2. **DynamoDB 테이블**: `popcorn-terraform-state-lock`
   - 파티션 키: `LockID` (String)
   - 온디맨드 결제 모드 권장

### Terraform 초기화
backend.tf 작성 후 다음 명령어로 백엔드를 초기화해야 합니다:

```bash
cd popcorn-terraform-feature/envs/prod
terraform init
```

### 상태 파일 마이그레이션
기존 로컬 상태 파일이 있는 경우:

```bash
terraform init -migrate-state
```

## 작업 완료 체크리스트

- [x] backend.tf 파일 생성
- [x] S3 버킷 이름 설정 (`popcorn-terraform-state`)
- [x] 상태 파일 키 설정 (`prod/terraform.tfstate`)
- [x] DynamoDB 테이블 설정 (`popcorn-terraform-state-lock`)
- [x] 암호화 활성화 (`encrypt = true`)
- [x] 코드 포맷 검증 (`terraform fmt -check`)
- [x] 작업 로그 작성

## 결론

Prod 환경의 backend.tf 파일이 성공적으로 작성되었습니다. 모든 요구사항을 충족하며, Dev 환경과 분리된 상태 파일 관리가 가능합니다. S3 백엔드와 DynamoDB 잠금 테이블을 통해 안전하고 협업 가능한 Terraform 상태 관리가 구현되었습니다.
