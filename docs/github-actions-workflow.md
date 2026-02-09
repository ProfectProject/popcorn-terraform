# GitHub Actions 워크플로우 가이드

## 개요

이 문서는 `popcorn-terraform-feature` 저장소의 GitHub Actions 워크플로우 구조와 동작 방식을 설명합니다.

## 워크플로우 구성

### 1. Terraform Plan 워크플로우

**파일**: `.github/workflows/terraform-plan.yml`

#### 트리거 조건

```yaml
on:
  pull_request:
    branches:
      - develop
      - main
```

- `develop` 또는 `main` 브랜치로 PR이 생성될 때 자동 실행
- 인프라 변경 사항을 사전에 검토하기 위한 목적

#### 환경 결정 로직

| 대상 브랜치 | 환경 | 작업 디렉토리 |
|------------|------|--------------|
| `main` | `prod` | `envs/prod` |
| `develop` | `dev` | `envs/dev` |

#### 실행 단계

##### 1. 코드 포맷 검증
```bash
terraform fmt -check -recursive
```
- 모든 Terraform 파일의 포맷 일관성 검사
- 실패 시 워크플로우 중단

##### 2. 변수 파일 준비
```bash
# GitHub Secrets에서 환경별 tfvars 가져오기
TFVARS_CONTENT: ${{ github.ref_name == 'main' && secrets.TFVARS_PROD || secrets.TFVARS_DEV }}
```
- `TFVARS_PROD` 또는 `TFVARS_DEV` 시크릿 사용
- 시크릿이 없으면 `terraform.tfvars.example` 파일 사용

##### 3. AWS 인증 (OIDC)
```yaml
- name: Configure AWS credentials (OIDC)
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ap-northeast-2
```
- OpenID Connect 기반 인증
- 장기 자격 증명(Access Key) 불필요
- IAM Role 기반으로 임시 자격 증명 발급

##### 4. Terraform 초기화 및 검증
```bash
terraform init      # 백엔드 초기화, 프로바이더 다운로드
terraform validate  # 구문 및 구성 검증
```

##### 5. Terraform Plan 실행
```bash
terraform plan -no-color | tee /tmp/plan.txt
```
- 변경 사항 미리보기
- 결과를 파일로 저장하여 PR 코멘트에 사용

##### 6. PR 코멘트 작성
- Plan 결과를 자동으로 PR에 코멘트
- 60,000자 제한 (초과 시 truncate)
- 팀원들이 변경 사항을 쉽게 검토 가능

##### 7. Discord 알림
```bash
# 성공 시: ✅ Terraform plan (dev) 성공
# 실패 시: ❌ Terraform plan (dev) 실패
```
- PR 제목, 브랜치 정보 포함
- 팀 협업 및 모니터링 용이

#### 권한 설정
```yaml
permissions:
  contents: read          # 코드 읽기
  pull-requests: write    # PR 코멘트 작성
  id-token: write         # OIDC 토큰 발급
```

---

### 2. Terraform Apply 워크플로우

**파일**: `.github/workflows/terraform-apply.yml`

#### 트리거 조건

```yaml
on:
  push:
    branches:
      - develop
      - main
```

- `develop` 또는 `main` 브랜치에 직접 push될 때 실행
- PR 머지 후 자동으로 인프라 변경 적용

#### 환경 결정 로직

| 브랜치 | 환경 | 작업 디렉토리 |
|--------|------|--------------|
| `main` | `prod` | `envs/prod` |
| `develop` | `dev` | `envs/dev` |

#### 실행 단계

##### 1. 변수 파일 준비
- Plan 워크플로우와 동일한 방식

##### 2. AWS 인증 (OIDC)
- Plan 워크플로우와 동일

##### 3. Terraform 초기화
```bash
terraform init
```

##### 4. Terraform Apply 실행
```bash
terraform apply -auto-approve
```
- 자동 승인으로 변경 사항 적용
- Plan 단계에서 이미 검토했으므로 안전

##### 5. Discord 알림
```bash
# 성공 시: ✅ Terraform apply (prod) 성공
# 실패 시: ❌ Terraform apply (prod) 실패
```
- 배포 결과를 팀에 즉시 공유

#### 환경 보호 설정
```yaml
environment: ${{ github.ref_name == 'main' && 'prod' || 'dev' }}
```
- GitHub Environment 기능 활용
- 프로덕션 환경은 추가 승인 게이트 설정 가능

#### 권한 설정
```yaml
permissions:
  contents: read    # 코드 읽기
  id-token: write   # OIDC 토큰 발급
```

---

## 워크플로우 특징

### 보안

#### ✅ OIDC 기반 인증
- 장기 자격 증명(Access Key/Secret Key) 불필요
- 임시 자격 증명으로 보안 강화
- 자격 증명 유출 위험 최소화

#### ✅ 최소 권한 원칙
```yaml
permissions:
  contents: read
  pull-requests: write
  id-token: write
```
- 필요한 권한만 명시적으로 부여
- 과도한 권한 부여 방지

#### ✅ 민감 정보 보호
- 변수 파일은 GitHub Secrets에 저장
- 코드에 하드코딩 금지
- 환경별 시크릿 분리 (`TFVARS_DEV`, `TFVARS_PROD`)

#### ✅ 환경별 승인 게이트
- GitHub Environment 기능으로 프로덕션 배포 제어
- 승인자 설정 가능
- 배포 타이밍 제어

### 자동화

#### ✅ PR 생성 시 자동 Plan
- 코드 리뷰 전 변경 사항 확인
- 예상치 못한 변경 사전 감지
- 팀원 간 협업 강화

#### ✅ 머지 시 자동 Apply
- 수동 개입 최소화
- 일관된 배포 프로세스
- 휴먼 에러 감소

#### ✅ Discord 알림
- 실시간 상태 모니터링
- 팀 전체 가시성 확보
- 빠른 문제 대응

### 환경 분리

#### ✅ 브랜치 기반 환경 구분
```
develop → dev 환경
main → prod 환경
```

#### ✅ 환경별 변수 파일 분리
```
envs/dev/terraform.tfvars
envs/prod/terraform.tfvars
```

#### ✅ 환경별 작업 디렉토리 분리
- 각 환경은 독립적인 상태 파일 관리
- 환경 간 간섭 방지

### 코드 품질

#### ✅ 포맷 검증
```bash
terraform fmt -check -recursive
```
- 코드 스타일 일관성 유지
- 가독성 향상

#### ✅ 구문 검증
```bash
terraform validate
```
- 문법 오류 사전 감지
- 배포 실패 방지

#### ✅ Plan 결과 리뷰
- PR 코멘트로 변경 사항 공유
- 팀원 검토 후 머지

---

## 워크플로우 흐름도

### Plan 워크플로우
```
PR 생성 (develop/main)
    ↓
코드 포맷 검증
    ↓
변수 파일 준비
    ↓
AWS 인증 (OIDC)
    ↓
terraform init
    ↓
terraform validate
    ↓
terraform plan
    ↓
PR 코멘트 작성
    ↓
Discord 알림
```

### Apply 워크플로우
```
PR 머지 (develop/main)
    ↓
변수 파일 준비
    ↓
AWS 인증 (OIDC)
    ↓
terraform init
    ↓
terraform apply -auto-approve
    ↓
Discord 알림
```

---

## 필수 설정

### GitHub Secrets

워크플로우 실행을 위해 다음 시크릿이 필요합니다:

| 시크릿 이름 | 설명 | 예시 |
|------------|------|------|
| `AWS_ROLE_ARN` | OIDC 인증용 IAM Role ARN | `arn:aws:iam::123456789012:role/github-actions-role` |
| `TFVARS_DEV` | 개발 환경 변수 파일 내용 | `project_name = "popcorn-dev"` |
| `TFVARS_PROD` | 프로덕션 환경 변수 파일 내용 | `project_name = "popcorn-prod"` |
| `DISCORD_WEBHOOK_URL` | Discord 알림용 웹훅 URL | `https://discord.com/api/webhooks/...` |

### AWS IAM Role 설정

#### 1. IAM Role 생성
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/popcorn-terraform-feature:*"
        }
      }
    }
  ]
}
```

#### 2. 필요한 권한 정책 연결
- EC2, VPC, EKS, RDS, ElastiCache 등 관리 권한
- S3 백엔드 접근 권한
- DynamoDB 락 테이블 접근 권한

### GitHub Environment 설정

#### 프로덕션 환경 보호
1. GitHub 저장소 → Settings → Environments
2. `prod` 환경 생성
3. 보호 규칙 설정:
   - Required reviewers: 승인자 지정
   - Wait timer: 배포 대기 시간 설정
   - Deployment branches: `main` 브랜치만 허용

---

## 개선 가능한 부분

### 1. 보안 스캔 추가

#### Checkov 통합
```yaml
- name: Run Checkov
  uses: bridgecrewio/checkov-action@master
  with:
    directory: ${{ env.ENV_DIR }}
    framework: terraform
```

**장점**:
- 보안 취약점 사전 감지
- 컴플라이언스 검증
- CIS 벤치마크 준수 확인

#### tfsec 통합
```yaml
- name: Run tfsec
  uses: aquasecurity/tfsec-action@v1.0.0
  with:
    working_directory: ${{ env.ENV_DIR }}
```

**장점**:
- 빠른 정적 분석
- AWS 보안 모범 사례 검증

### 2. 비용 예측

#### Infracost 통합
```yaml
- name: Run Infracost
  uses: infracost/actions/setup@v2
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate cost estimate
  run: |
    infracost breakdown --path=${{ env.ENV_DIR }} \
      --format=json --out-file=/tmp/infracost.json
```

**장점**:
- 변경 사항의 비용 영향 예측
- PR 코멘트로 비용 변화 공유
- 예산 초과 방지

### 3. Plan 파일 저장

#### 아티팩트 저장
```yaml
- name: Save plan
  run: terraform plan -out=tfplan

- name: Upload plan
  uses: actions/upload-artifact@v3
  with:
    name: terraform-plan
    path: ${{ env.ENV_DIR }}/tfplan
```

**장점**:
- Plan과 Apply 간 일관성 보장
- 예상치 못한 변경 방지
- 감사 추적 강화

### 4. Drift 감지

#### 정기적인 Drift 검사
```yaml
on:
  schedule:
    - cron: '0 9 * * 1'  # 매주 월요일 오전 9시
```

**장점**:
- 수동 변경 감지
- 코드와 실제 인프라 간 차이 확인
- 인프라 일관성 유지

### 5. 병렬 실행 방지

#### Concurrency 설정
```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false
```

**장점**:
- 동시 실행으로 인한 충돌 방지
- 상태 파일 락 경합 방지
- 안정적인 배포

### 6. 테스트 환경 추가

#### 스테이징 환경
```yaml
on:
  push:
    branches:
      - develop
      - staging
      - main
```

**장점**:
- 프로덕션 배포 전 최종 검증
- 리스크 감소
- 단계적 배포 가능

---

## 중요: 로컬 실행 금지 정책

### ⚠️ 로컬에서 terraform apply 실행 시 문제점

현재 워크플로우는 **GitOps 방식**으로 설계되어 있습니다. 로컬에서 `terraform apply`를 실행하면 다음과 같은 문제가 발생합니다:

#### Terraform 원격 백엔드

**중요**: 로컬에서 실행해도 상태 파일은 **자동으로 S3에 저장**됩니다!

> 💡 **상세 정보**: 백엔드 동작 방식, 상태 파일 관리, 락 메커니즘, 문제 해결 등은 [Terraform 백엔드 가이드](./terraform-backend-guide.md)를 참고하세요.

#### 1. 감사 추적 손실 (가장 큰 문제)
```
개발자 로컬에서 실행:
  terraform apply
  → S3 상태 파일 업데이트됨 ✅
  → AWS 리소스 변경됨 ✅
  → GitHub Actions 로그 없음 ❌
  → Discord 알림 없음 ❌
  → 누가 변경했는지 추적 불가 ❌

코드를 Git에 푸시:
  → GitHub Actions 실행
  → terraform apply
  → 결과: "No changes. Infrastructure is up-to-date."
  → 실제 변경 내역이 로그에 남지 않음
```

**문제점**:
- 누가, 언제, 무엇을 변경했는지 알 수 없음
- 문제 발생 시 원인 파악 어려움
- 팀원들이 변경 사항을 모름

#### 2. 동시 실행 충돌 (Lock Contention)

여러 프로세스가 동시에 terraform을 실행하면 DynamoDB 락 경합이 발생합니다.

**문제점**:
- DynamoDB 락 타임아웃
- 예측 불가능한 실행 순서
- 상태 파일 충돌 가능성

> 💡 **상세 정보**: 락 메커니즘과 충돌 해결 방법은 [Terraform 백엔드 가이드 - 상태 파일 락 메커니즘](./terraform-backend-guide.md#상태-파일-락-메커니즘)을 참고하세요.

#### 3. 코드 리뷰 우회
```
로컬 실행:
  terraform apply
  → 즉시 인프라 변경
  → 팀원 검토 없음
  → 실수 발견 기회 없음

올바른 방식:
  PR 생성
  → terraform plan 결과 공유
  → 팀원 리뷰
  → 승인 후 머지
  → terraform apply
```

**문제점**:
- PR 프로세스 우회
- 팀원의 검토 없이 인프라 변경
- 실수나 보안 문제 사전 발견 불가

#### 4. 환경 변수 불일치
```
로컬 환경:
  terraform.tfvars (로컬 파일)
  → 개발자마다 다를 수 있음
  → 민감 정보 노출 위험

GitHub Actions:
  GitHub Secrets (TFVARS_DEV, TFVARS_PROD)
  → 중앙 관리
  → 일관된 설정
```

**문제점**:
- 로컬 변수 파일과 Secrets 불일치
- 예상치 못한 설정으로 배포
- 민감 정보 로컬 저장 위험

### ✅ 올바른 작업 방식

#### 로컬에서는 plan만 실행
```bash
cd envs/dev
terraform init
terraform plan  # ✅ 허용: 변경 사항 미리보기만
# terraform apply  # ❌ 금지: 절대 실행하지 말 것
```

#### 모든 변경은 Git을 통해
```bash
# 1. 코드 수정
vim envs/dev/main.tf

# 2. 로컬 검증 (plan만)
terraform plan

# 3. Git 커밋 및 푸시
git add .
git commit -m "feat: add RDS read replica"
git push origin feature/add-rds-replica

# 4. PR 생성
# → GitHub Actions가 자동으로 plan 실행
# → 팀원 리뷰

# 5. PR 머지
# → GitHub Actions가 자동으로 apply 실행
```

### 🔒 로컬 실행 방지 방법

#### 1. Pre-commit Hook 설정
```bash
# .git/hooks/pre-commit
#!/bin/bash
if git diff --cached --name-only | grep -q "\.tf$"; then
  echo "⚠️  Terraform 파일이 변경되었습니다."
  echo "❌ 로컬에서 terraform apply를 실행하지 마세요!"
  echo "✅ PR을 생성하여 GitHub Actions를 통해 배포하세요."
fi
```

#### 2. IAM 권한 분리
```
로컬 개발자: ReadOnly 권한만 부여
GitHub Actions: 전체 권한 부여
```

**IAM Policy 예시**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "rds:Describe*",
        "eks:Describe*",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "ec2:Create*",
        "ec2:Delete*",
        "ec2:Modify*",
        "rds:Create*",
        "rds:Delete*",
        "rds:Modify*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### 3. 상태 파일 락 설정
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "popcorn-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"  # 락 테이블
    encrypt        = true
  }
}
```

#### 4. 팀 규칙 문서화
```markdown
# 인프라 변경 규칙

## 금지 사항
- ❌ 로컬에서 terraform apply 실행
- ❌ AWS 콘솔에서 수동 변경
- ❌ 상태 파일 직접 수정

## 허용 사항
- ✅ 로컬에서 terraform plan 실행
- ✅ PR을 통한 변경
- ✅ GitHub Actions를 통한 배포
```

### 🚨 긴급 상황 대응

#### 로컬에서 실수로 apply를 실행한 경우

1. **즉시 팀에 알림**
   - Discord나 Slack에 공지

2. **코드와 상태 동기화**
   - 현재 상태를 확인하고 코드 업데이트
   - 필요시 `terraform import` 사용

3. **PR 생성하여 정상화**
   ```bash
   git add .
   git commit -m "fix: sync state after local apply"
   git push
   # PR 생성 및 머지
   ```

> 💡 **상세 정보**: 상태 파일 복구, 락 해제 등 자세한 문제 해결 방법은 [Terraform 백엔드 가이드 - 문제 해결](./terraform-backend-guide.md#문제-해결)을 참고하세요.

### 📊 상태 불일치 감지

#### Drift 감지 워크플로우 추가 (권장)
```yaml
name: terraform-drift-detection

on:
  schedule:
    - cron: '0 9 * * 1'  # 매주 월요일 오전 9시

jobs:
  detect-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Terraform plan
        run: terraform plan -detailed-exitcode
        # Exit code 2 = 변경 사항 있음 (drift 감지)
        
      - name: Notify if drift detected
        if: failure()
        run: |
          # Discord 알림
          echo "⚠️ Drift 감지! 코드와 실제 인프라가 다릅니다."
```

## 모범 사례

### PR 워크플로우

1. **기능 브랜치 생성**
   ```bash
   git checkout -b feature/add-rds-replica
   ```

2. **Terraform 코드 작성**
   ```bash
   cd envs/dev
   # 코드 수정
   ```

3. **로컬 검증**
   ```bash
   terraform fmt -recursive
   terraform validate
   terraform plan
   ```

4. **PR 생성**
   - `develop` 브랜치로 PR 생성
   - Plan 워크플로우 자동 실행
   - PR 코멘트에서 변경 사항 확인

5. **코드 리뷰**
   - 팀원이 Plan 결과 검토
   - 코드 리뷰 진행
   - 승인 후 머지

6. **자동 배포**
   - 머지 시 Apply 워크플로우 자동 실행
   - Discord로 배포 결과 확인

### 긴급 변경 시

1. **Hotfix 브랜치 생성**
   ```bash
   git checkout -b hotfix/security-group-fix main
   ```

2. **변경 사항 적용**
   ```bash
   cd envs/prod
   # 긴급 수정
   ```

3. **빠른 검증**
   ```bash
   terraform plan
   ```

4. **PR 생성 및 긴급 머지**
   - `main` 브랜치로 PR 생성
   - 최소 1명 승인 후 즉시 머지
   - 자동 배포 확인

### 롤백 절차

1. **문제 발생 감지**
   - Discord 알림 또는 모니터링 확인

2. **이전 커밋으로 Revert**
   ```bash
   git revert HEAD
   git push origin main
   ```

3. **자동 롤백**
   - Apply 워크플로우가 이전 상태로 복원
   - Discord로 롤백 완료 확인

---

## 문제 해결

### 워크플로우 실패 시

#### 1. 포맷 검증 실패
```
Error: terraform fmt -check failed
```

**해결 방법**:
```bash
terraform fmt -recursive
git add .
git commit -m "fix: format terraform files"
git push
```

#### 2. AWS 인증 실패
```
Error: failed to assume role
```

**확인 사항**:
- `AWS_ROLE_ARN` 시크릿이 올바른지 확인
- IAM Role의 Trust Policy 확인
- OIDC Provider 설정 확인

#### 3. Plan 실패
```
Error: terraform plan failed
```

**확인 사항**:
- 변수 파일이 올바른지 확인
- AWS 리소스 제한 확인
- 백엔드 상태 파일 확인

#### 4. Apply 실패
```
Error: terraform apply failed
```

**대응 방법**:
1. Discord 알림 확인
2. GitHub Actions 로그 확인
3. AWS 콘솔에서 리소스 상태 확인
4. 필요시 수동 롤백

### Discord 알림이 오지 않을 때

**확인 사항**:
- `DISCORD_WEBHOOK_URL` 시크릿 설정 확인
- Discord 웹훅이 활성화되어 있는지 확인
- 워크플로우 로그에서 알림 단계 확인

---

## 참고 자료

### 공식 문서
- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [AWS OIDC 인증](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

### 관련 문서
- [프로젝트 구조 가이드](../../.kiro/steering/project-structure.md)
- [인프라 설계 문서](./infrastructure-design.md)
- [Terraform 파일 구조](./terraform-file-organization.md)

### 도구
- [Checkov](https://www.checkov.io/)
- [tfsec](https://github.com/aquasecurity/tfsec)
- [Infracost](https://www.infracost.io/)
- [Terraform](https://www.terraform.io/)
