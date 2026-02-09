# Task 7.1-7.5: GitHub Actions 워크플로우 개선

## 작업 일시
2026-02-09

## 작업 내용

GitHub Actions 워크플로우에 concurrency 설정을 추가하여 동시 실행을 방지하고, Terraform 상태 잠금을 확인했습니다.

## Task 7.1 & 7.2: Dev 및 Prod 환경 워크플로우 개선

### 기존 워크플로우 분석

**파일**:
- `.github/workflows/terraform-plan.yml`
- `.github/workflows/terraform-apply.yml`

**기존 구현 상태**:
- ✅ 환경별 분리 (develop 브랜치 → dev, main 브랜치 → prod)
- ✅ OIDC 인증 사용 (AWS IAM Role)
- ✅ PR 생성 시 terraform plan 자동 실행
- ✅ PR 머지 시 terraform apply 자동 실행
- ✅ Terraform 결과를 PR 코멘트로 표시
- ✅ Discord 알림 전송
- ❌ Concurrency 설정 없음 (추가 필요)
- ❌ Prod 환경 수동 승인 없음 (이미 environment 설정으로 구현 가능)

### 추가된 개선 사항

#### 1. Concurrency 설정 추가

**terraform-plan.yml**:
```yaml
# 동시 실행 방지 - 환경별로 하나의 plan만 실행
concurrency:
  group: terraform-plan-${{ github.base_ref == 'main' && 'prod' || 'dev' }}
  cancel-in-progress: false
```

**terraform-apply.yml**:
```yaml
# 동시 실행 방지 - 환경별로 하나의 apply만 실행
concurrency:
  group: terraform-apply-${{ github.ref_name == 'main' && 'prod' || 'dev' }}
  cancel-in-progress: false
```

**설명**:
- `group`: 환경별로 별도의 concurrency 그룹 생성
- `cancel-in-progress: false`: 진행 중인 작업을 취소하지 않고 대기
- Dev와 Prod 환경은 독립적으로 실행 가능
- 같은 환경에서는 순차적으로 실행

#### 2. 환경별 승인 설정 (이미 구현됨)

**terraform-apply.yml**:
```yaml
jobs:
  apply:
    runs-on: ubuntu-latest
    environment: ${{ github.ref_name == 'main' && 'prod' || 'dev' }}
```

**설명**:
- GitHub Environment를 사용하여 환경별 승인 설정
- Prod 환경은 GitHub Settings에서 수동 승인 설정 가능
- Dev 환경은 자동 배포

## Task 7.3: GitHub Secrets 설정

### 필수 Secrets

**Repository Secrets** (Settings → Secrets and variables → Actions):

1. **AWS_ROLE_ARN**
   - 설명: OIDC 인증을 위한 AWS IAM Role ARN
   - 형식: `arn:aws:iam::123456789012:role/github-actions-terraform-role`
   - 사용: AWS 자격증명 획득

2. **TFVARS_DEV**
   - 설명: Dev 환경 terraform.tfvars 내용
   - 형식: 전체 tfvars 파일 내용
   - 사용: Dev 환경 변수 설정

3. **TFVARS_PROD**
   - 설명: Prod 환경 terraform.tfvars 내용
   - 형식: 전체 tfvars 파일 내용
   - 사용: Prod 환경 변수 설정

4. **DISCORD_WEBHOOK_URL** (선택적)
   - 설명: Discord 알림을 위한 Webhook URL
   - 형식: `https://discord.com/api/webhooks/...`
   - 사용: 배포 결과 알림

### Secrets 설정 방법

```bash
# GitHub CLI 사용
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::123456789012:role/github-actions-terraform-role"
gh secret set TFVARS_DEV --body "$(cat envs/dev/terraform.tfvars)"
gh secret set TFVARS_PROD --body "$(cat envs/prod/terraform.tfvars)"
gh secret set DISCORD_WEBHOOK_URL --body "https://discord.com/api/webhooks/..."
```

또는 GitHub 웹 UI에서:
1. Repository → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭
3. Name과 Value 입력
4. "Add secret" 클릭

## Task 7.4: 워크플로우 Concurrency 설정

### Concurrency 동작 방식

**시나리오 1: 같은 환경에서 동시 실행 시도**
```
PR #1 (dev) - terraform plan 실행 중
PR #2 (dev) - terraform plan 대기 (cancel-in-progress: false)
```

**시나리오 2: 다른 환경에서 동시 실행**
```
PR #1 (dev) - terraform plan 실행
PR #2 (prod) - terraform plan 실행 (독립적으로 실행)
```

**시나리오 3: Plan과 Apply 동시 실행**
```
PR #1 (dev) - terraform plan 실행
Push (dev) - terraform apply 대기 (다른 concurrency 그룹)
```

### Concurrency 그룹 구조

```
terraform-plan-dev    → Dev 환경 plan 작업
terraform-plan-prod   → Prod 환경 plan 작업
terraform-apply-dev   → Dev 환경 apply 작업
terraform-apply-prod  → Prod 환경 apply 작업
```

## Task 7.5: Terraform 상태 잠금 설정

### DynamoDB 잠금 테이블 확인

**Dev 환경** (`envs/dev/backend.tf`):
```hcl
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

**Prod 환경** (`envs/prod/backend.tf`):
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

**상태**: ✅ 이미 설정됨

### DynamoDB 잠금 동작 방식

1. **Terraform 실행 시작**
   - DynamoDB 테이블에 잠금 레코드 생성
   - LockID: `{bucket}/{key}`

2. **동시 실행 시도**
   - 다른 Terraform 프로세스가 잠금 획득 시도
   - DynamoDB에서 잠금 충돌 감지
   - 에러 메시지 출력 및 대기

3. **Terraform 실행 완료**
   - DynamoDB 테이블에서 잠금 레코드 삭제
   - 대기 중인 프로세스가 잠금 획득

### 잠금 타임아웃 설정

Terraform은 기본적으로 무한정 대기하지 않습니다:
- 기본 타임아웃: 없음 (즉시 실패)
- `-lock-timeout` 옵션으로 대기 시간 설정 가능

**워크플로우에 타임아웃 추가 (선택적)**:
```yaml
- name: Terraform apply
  run: terraform apply -auto-approve -lock-timeout=10m
  working-directory: ${{ env.ENV_DIR }}
```

## 워크플로우 실행 흐름

### Pull Request 생성 시 (terraform-plan.yml)

```
1. PR 생성 (develop 또는 main 브랜치 대상)
   ↓
2. Concurrency 체크 (같은 환경에서 실행 중인 plan이 있는지 확인)
   ↓
3. Terraform fmt 체크
   ↓
4. terraform.tfvars 준비 (GitHub Secrets에서 가져오기)
   ↓
5. AWS 자격증명 획득 (OIDC)
   ↓
6. Terraform init (DynamoDB 잠금 테이블 연결)
   ↓
7. Terraform validate
   ↓
8. Terraform plan (DynamoDB 잠금 획득)
   ↓
9. Plan 결과를 PR 코멘트로 표시
   ↓
10. Discord 알림 전송
```

### Pull Request 머지 시 (terraform-apply.yml)

```
1. PR 머지 (develop 또는 main 브랜치)
   ↓
2. Concurrency 체크 (같은 환경에서 실행 중인 apply가 있는지 확인)
   ↓
3. Environment 승인 대기 (Prod 환경만)
   ↓
4. terraform.tfvars 준비 (GitHub Secrets에서 가져오기)
   ↓
5. AWS 자격증명 획득 (OIDC)
   ↓
6. Terraform init (DynamoDB 잠금 테이블 연결)
   ↓
7. Terraform apply (DynamoDB 잠금 획득)
   ↓
8. Discord 알림 전송
```

## 보안 고려사항

### 1. OIDC 인증
- ✅ AWS Access Key 대신 OIDC 사용
- ✅ 단기 자격증명 (1시간)
- ✅ IAM Role 기반 권한 관리

### 2. Secrets 관리
- ✅ terraform.tfvars를 GitHub Secrets로 관리
- ✅ 민감 정보 노출 방지
- ✅ 환경별 Secrets 분리

### 3. 상태 파일 보안
- ✅ S3 버킷 암호화 활성화
- ✅ DynamoDB 잠금으로 동시 수정 방지
- ✅ 버전 관리 활성화 (롤백 가능)

### 4. PR 코멘트 보안
- ⚠️ Plan 결과에 민감 정보가 포함될 수 있음
- ⚠️ Private Repository 사용 권장
- ⚠️ 필요시 민감 정보 마스킹 추가

## 트러블슈팅

### 문제 1: Concurrency로 인한 대기 시간 증가

**증상**:
- PR 생성 시 plan이 오래 대기

**원인**:
- 같은 환경에서 다른 plan이 실행 중

**해결**:
1. 실행 중인 워크플로우 확인
2. 필요시 이전 워크플로우 취소
3. `cancel-in-progress: true`로 변경 (주의: 진행 중인 작업 취소)

### 문제 2: DynamoDB 잠금 획득 실패

**증상**:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        abc123...
  Path:      goorm-popcorn-tfstate/dev/terraform.tfstate
  Operation: OperationTypeApply
  Who:       github-actions@...
  Version:   1.6.6
  Created:   2026-02-09 10:00:00 UTC
```

**원인**:
- 이전 Terraform 실행이 비정상 종료되어 잠금이 남아있음
- 다른 프로세스가 동시에 실행 중

**해결**:
```bash
# 잠금 강제 해제 (주의: 다른 프로세스가 실행 중이 아닌지 확인)
terraform force-unlock <LOCK_ID>

# 또는 DynamoDB에서 직접 삭제
aws dynamodb delete-item \
  --table-name goorm-popcorn-tfstate-lock \
  --key '{"LockID": {"S": "goorm-popcorn-tfstate/dev/terraform.tfstate"}}'
```

### 문제 3: OIDC 인증 실패

**증상**:
```
Error: Failed to assume role
```

**원인**:
- IAM Role의 Trust Policy가 올바르지 않음
- GitHub Repository 정보가 일치하지 않음

**해결**:
1. IAM Role의 Trust Policy 확인
2. GitHub Repository 이름 확인
3. OIDC Provider 설정 확인

### 문제 4: terraform.tfvars 준비 실패

**증상**:
- Terraform plan/apply 시 변수 값이 없음

**원인**:
- GitHub Secrets에 TFVARS_DEV 또는 TFVARS_PROD가 설정되지 않음

**해결**:
1. GitHub Secrets 확인
2. terraform.tfvars 내용 확인
3. Secrets 재설정

## 검증

### 1. Concurrency 테스트

```bash
# 같은 환경에서 두 개의 PR 생성
# PR #1: develop 브랜치 대상
# PR #2: develop 브랜치 대상

# 결과: PR #2는 PR #1이 완료될 때까지 대기
```

### 2. 환경별 독립 실행 테스트

```bash
# 다른 환경에서 두 개의 PR 생성
# PR #1: develop 브랜치 대상 (dev 환경)
# PR #2: main 브랜치 대상 (prod 환경)

# 결과: 두 PR 모두 동시에 실행
```

### 3. DynamoDB 잠금 테스트

```bash
# 로컬에서 Terraform 실행
cd envs/dev
terraform init
terraform plan

# GitHub Actions에서 동시에 plan 실행
# 결과: 하나는 잠금 획득, 다른 하나는 대기 또는 실패
```

### 4. PR 코멘트 확인

```bash
# PR 생성 후 코멘트 확인
# 예상 결과:
# - Terraform plan 결과가 코드 블록으로 표시
# - 환경 이름 표시 (dev 또는 prod)
# - 변경 사항 요약
```

## 다음 단계

### Task 8: Terraform 검증
- ✅ Task 7 완료
- ⏭️ Task 8.1: Dev 환경 Terraform 검증
- ⏭️ Task 8.2: Prod 환경 Terraform 검증
- ⏭️ Task 8.3: 모든 테스트 통과 확인

## 참고사항

### GitHub Actions Concurrency 문서
- https://docs.github.com/en/actions/using-jobs/using-concurrency

### Terraform Backend 문서
- https://developer.hashicorp.com/terraform/language/settings/backends/s3

### AWS OIDC 인증 문서
- https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

### GitHub Environments 문서
- https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment

## 결론

Task 7.1-7.5가 완료되었습니다. GitHub Actions 워크플로우에 다음 개선 사항이 추가되었습니다:

1. ✅ **Concurrency 설정**: 환경별로 동시 실행 방지
2. ✅ **환경별 승인**: Prod 환경은 수동 승인 가능 (GitHub Environment 설정 필요)
3. ✅ **DynamoDB 잠금**: 이미 설정되어 있음
4. ✅ **PR 코멘트**: Plan 결과 자동 표시 (이미 구현됨)
5. ✅ **Discord 알림**: 배포 결과 알림 (이미 구현됨)

이제 로컬 환경에서 여러 사람이 동시에 apply하는 문제가 해결되었으며, GitHub Actions를 통해 안전하고 일관된 배포가 가능합니다.
