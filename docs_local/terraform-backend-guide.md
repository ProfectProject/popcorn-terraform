# Terraform 백엔드 가이드

## 개요

이 문서는 Terraform 원격 백엔드(Remote Backend)의 동작 방식과 상태 파일 관리에 대해 설명합니다.

## 백엔드 구성

### 현재 설정

프로젝트는 **S3 백엔드**를 사용하여 상태 파일을 원격으로 관리합니다.

```hcl
# envs/dev/backend.tf
terraform {
  backend "s3" {
    bucket         = "goorm-popcorn-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "goorm-popcorn-tfstate-lock"
    encrypt        = true
  }
}
```

### 환경별 상태 파일 경로

| 환경 | S3 Key | 설명 |
|------|--------|------|
| Bootstrap | `bootstrap/terraform.tfstate` | S3 버킷 및 DynamoDB 테이블 |
| Global ECR | `global/ecr/terraform.tfstate` | ECR 레지스트리 |
| Global Route53 | `global/route53-acm/terraform.tfstate` | Route53 및 ACM |
| Dev | `dev/terraform.tfstate` | 개발 환경 인프라 |
| Prod | `prod/terraform.tfstate` | 프로덕션 환경 인프라 |

## 원격 백엔드 동작 방식

### 1. 초기화 (terraform init)

```
terraform init 실행
    ↓
backend.tf 읽기
    ↓
S3 버킷 연결
    ↓
현재 상태 파일 다운로드
s3://goorm-popcorn-tfstate/dev/terraform.tfstate
    ↓
로컬 .terraform/ 디렉토리에 캐시
```

**중요**: 상태 파일은 로컬에 저장되지 않고 S3에서 관리됩니다.

### 2. Plan 실행 (terraform plan)

```
terraform plan 실행
    ↓
S3에서 최신 상태 다운로드
    ↓
현재 코드와 상태 비교
    ↓
변경 사항 계산
    ↓
변경 계획 출력 (상태 파일 수정 없음)
```

### 3. Apply 실행 (terraform apply)

```
terraform apply 실행
    ↓
DynamoDB 락 획득 시도
테이블: goorm-popcorn-tfstate-lock
    ↓
락 획득 성공
    ↓
S3에서 최신 상태 다운로드
    ↓
AWS 리소스 변경
    ↓
새로운 상태 생성
    ↓
S3에 상태 업로드 (자동)
    ↓
DynamoDB 락 해제
```

**핵심**: 로컬에서 실행해도 상태 파일은 **자동으로 S3에 저장**됩니다!

## 상태 파일 락 메커니즘

### DynamoDB 락 테이블

```
테이블 이름: goorm-popcorn-tfstate-lock
Primary Key: LockID (String)

동작 방식:
1. terraform apply 시작
   → DynamoDB에 락 레코드 생성
   
2. 다른 실행이 시도
   → 락 레코드 존재 확인
   → 대기 또는 실패
   
3. terraform apply 완료
   → 락 레코드 삭제
```

### 락 충돌 시나리오

#### 시나리오 1: 순차 실행
```
프로세스 A:
  terraform apply 시작
  → 락 획득 ✅
  → 리소스 변경 중... (5분)

프로세스 B:
  terraform apply 시작
  → 락 대기 ⏳
  → 타임아웃 (기본 10분)
  → 에러 발생
```

#### 시나리오 2: 강제 락 해제
```
상황: 프로세스가 비정상 종료되어 락이 남아있음

해결:
terraform force-unlock <LOCK_ID>

주의: 다른 프로세스가 실행 중일 수 있으므로 신중히 사용
```

## 로컬 vs GitHub Actions 실행

### 로컬에서 실행 시

```
개발자 로컬:
  terraform init
  → AWS 자격 증명 (로컬 프로파일)
  → S3 상태 다운로드
  
  terraform apply
  → DynamoDB 락 획득
  → AWS 리소스 변경
  → S3 상태 업로드 ✅
  → 로그: 로컬 터미널만
  → 추적: 없음 ❌
```

### GitHub Actions에서 실행 시

```
GitHub Actions:
  terraform init
  → AWS 자격 증명 (OIDC)
  → S3 상태 다운로드
  
  terraform apply
  → DynamoDB 락 획득
  → AWS 리소스 변경
  → S3 상태 업로드 ✅
  → 로그: GitHub Actions ✅
  → Discord 알림 ✅
  → 추적: Git 커밋 ✅
```

**차이점**: 상태 파일은 동일하게 S3에 저장되지만, 로컬 실행은 추적이 불가능합니다.

## 상태 파일 관리

### 상태 파일 구조

```json
{
  "version": 4,
  "terraform_version": "1.6.6",
  "serial": 42,
  "lineage": "abc-123-def",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "aws_vpc",
      "name": "main",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "attributes": {
            "id": "vpc-12345",
            "cidr_block": "10.0.0.0/16"
          }
        }
      ]
    }
  ]
}
```

### 상태 파일 버전 관리

S3 버킷은 **버전 관리**가 활성화되어 있어야 합니다:

```hcl
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = "goorm-popcorn-tfstate"
  
  versioning_configuration {
    status = "Enabled"
  }
}
```

**장점**:
- 실수로 상태 파일 삭제 시 복구 가능
- 이전 버전으로 롤백 가능
- 변경 이력 추적

### 상태 파일 암호화

```hcl
terraform {
  backend "s3" {
    bucket  = "goorm-popcorn-tfstate"
    encrypt = true  # 서버 측 암호화 활성화
  }
}
```

**보안**:
- AES-256 암호화
- 민감한 정보 보호 (비밀번호, 키 등)
- 규정 준수 (GDPR, HIPAA 등)

## 상태 파일 작업

### 상태 확인

```bash
# 현재 상태 보기
terraform show

# 특정 리소스 상태 보기
terraform state show aws_vpc.main

# 상태 파일 목록
terraform state list
```

### 상태 다운로드

```bash
# S3에서 상태 파일 다운로드
terraform state pull > current-state.json

# 특정 버전 다운로드 (AWS CLI)
aws s3api get-object \
  --bucket goorm-popcorn-tfstate \
  --key dev/terraform.tfstate \
  --version-id <VERSION_ID> \
  state-backup.json
```

### 상태 백업

```bash
# 수동 백업
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).json

# S3 버전 관리로 자동 백업됨
aws s3api list-object-versions \
  --bucket goorm-popcorn-tfstate \
  --prefix dev/terraform.tfstate
```

### 리소스 임포트

```bash
# 기존 AWS 리소스를 상태 파일에 추가
terraform import aws_vpc.main vpc-12345

# 임포트 후 상태 확인
terraform state show aws_vpc.main
```

### 리소스 제거

```bash
# 상태 파일에서만 제거 (AWS 리소스는 유지)
terraform state rm aws_vpc.main

# 실제 리소스도 삭제
terraform destroy -target=aws_vpc.main
```

## 문제 해결

### 1. 상태 파일 락이 걸린 경우

**증상**:
```
Error: Error acquiring the state lock

Lock Info:
  ID:        abc-123-def
  Path:      goorm-popcorn-tfstate/dev/terraform.tfstate
  Operation: OperationTypeApply
  Who:       user@hostname
  Version:   1.6.6
  Created:   2025-02-08 10:30:00 UTC
```

**원인**:
- 이전 실행이 비정상 종료
- 네트워크 문제로 락 해제 실패
- 다른 프로세스가 실행 중

**해결**:
```bash
# 1. 다른 프로세스가 실행 중인지 확인
# GitHub Actions, 다른 팀원 등

# 2. 확실히 실행 중이 아니면 강제 해제
terraform force-unlock abc-123-def

# 3. DynamoDB에서 직접 확인
aws dynamodb scan \
  --table-name goorm-popcorn-tfstate-lock
```

### 2. 상태 파일 손상

**증상**:
```
Error: Failed to load state: state snapshot was created by Terraform v1.7.0, 
which is newer than current v1.6.6
```

**해결**:
```bash
# 1. S3에서 이전 버전 복구
aws s3api list-object-versions \
  --bucket goorm-popcorn-tfstate \
  --prefix dev/terraform.tfstate

# 2. 특정 버전으로 복원
aws s3api copy-object \
  --bucket goorm-popcorn-tfstate \
  --copy-source goorm-popcorn-tfstate/dev/terraform.tfstate?versionId=<VERSION_ID> \
  --key dev/terraform.tfstate

# 3. 상태 확인
terraform state pull
```

### 3. 상태 불일치 (Drift)

**증상**:
```
# Plan 실행 시 예상치 못한 변경 사항
terraform plan
...
  # aws_vpc.main will be updated in-place
  ~ resource "aws_vpc" "main" {
      ~ tags = {
          - "Manual" = "true"
        }
    }
```

**원인**:
- AWS 콘솔에서 수동 변경
- 다른 도구로 리소스 수정
- 로컬에서 apply 실행

**해결**:
```bash
# 1. 현재 상태 확인
terraform plan

# 2. 실제 인프라를 코드에 맞춤
terraform apply

# 또는

# 3. 코드를 실제 인프라에 맞춤
terraform refresh
terraform state pull > current-state.json
# 코드 수정
```

### 4. 동시 실행 충돌

**증상**:
```
Error: Error acquiring the state lock

Another Terraform process is running.
```

**예방**:
```yaml
# GitHub Actions에 concurrency 설정
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false
```

**해결**:
- 실행 중인 프로세스 완료 대기
- 필요시 프로세스 취소 후 재실행

## 모범 사례

### 1. 상태 파일 직접 수정 금지

```bash
# ❌ 절대 하지 말 것
vim terraform.tfstate
terraform state push terraform.tfstate

# ✅ 올바른 방법
terraform state rm aws_vpc.main
terraform import aws_vpc.main vpc-12345
```

### 2. 정기적인 백업

```bash
# 크론잡 또는 GitHub Actions로 자동화
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
terraform state pull > backups/state-${DATE}.json
```

### 3. 상태 파일 접근 제한

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:role/github-actions-role"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::goorm-popcorn-tfstate/*"
    }
  ]
}
```

### 4. 환경별 상태 파일 분리

```
✅ 올바른 구조:
s3://goorm-popcorn-tfstate/
  ├── dev/terraform.tfstate
  ├── prod/terraform.tfstate
  └── global/ecr/terraform.tfstate

❌ 잘못된 구조:
s3://goorm-popcorn-tfstate/terraform.tfstate
(모든 환경이 하나의 상태 파일 공유)
```

### 5. 상태 파일 암호화

```hcl
# S3 버킷 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = "goorm-popcorn-tfstate"

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

## 상태 파일 마이그레이션

### 로컬에서 원격으로 마이그레이션

```bash
# 1. 현재 로컬 상태 백업
cp terraform.tfstate terraform.tfstate.backup

# 2. backend.tf 추가
cat > backend.tf <<EOF
terraform {
  backend "s3" {
    bucket = "goorm-popcorn-tfstate"
    key    = "dev/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
EOF

# 3. 마이그레이션 실행
terraform init -migrate-state

# 4. 확인
terraform state pull
```

### 다른 S3 버킷으로 마이그레이션

```bash
# 1. 현재 상태 백업
terraform state pull > state-backup.json

# 2. backend.tf 수정
# bucket 이름 변경

# 3. 재초기화
terraform init -migrate-state -force-copy

# 4. 확인
terraform state pull
```

## 보안 고려사항

### 1. 상태 파일에 포함되는 민감 정보

상태 파일에는 다음과 같은 민감 정보가 포함될 수 있습니다:
- 데이터베이스 비밀번호
- API 키
- 인증서 개인 키
- 환경 변수

**대책**:
- S3 암호화 활성화
- 접근 권한 최소화
- 버전 관리 활성화
- 정기적인 감사

### 2. IAM 권한 최소화

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::goorm-popcorn-tfstate/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:ap-northeast-2:ACCOUNT_ID:table/goorm-popcorn-tfstate-lock"
    }
  ]
}
```

### 3. 감사 로깅

```hcl
# S3 버킷 로깅 활성화
resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = "goorm-popcorn-tfstate"

  target_bucket = "goorm-popcorn-logs"
  target_prefix = "terraform-state-access/"
}
```

## 참고 자료

### 공식 문서
- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
- [S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [State Locking](https://developer.hashicorp.com/terraform/language/state/locking)

### 관련 문서
- [GitHub Actions 워크플로우 가이드](./github-actions-workflow.md)
- [프로젝트 구조 가이드](../../.kiro/steering/project-structure.md)

### AWS 문서
- [S3 버전 관리](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [DynamoDB 조건부 쓰기](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/WorkingWithItems.html#WorkingWithItems.ConditionalUpdate)
