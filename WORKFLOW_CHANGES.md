# GitHub Actions 워크플로우 변경 사항

## 변경 이유

Dev 환경을 건너뛰고 Prod 환경만 배포하기 위해 워크플로우를 수정했습니다.

## 변경 내용

### 이전 구조
```yaml
# terraform-apply.yml
on:
  push:
    branches:
      - develop  # Dev 환경 배포
      - main     # Prod 환경 배포

# 브랜치에 따라 환경 자동 선택
ENV_NAME: ${{ github.ref_name == 'main' && 'prod' || 'dev' }}
```

### 변경 후 구조
```yaml
# terraform-apply.yml
on:
  push:
    branches:
      - main  # Prod 환경만 배포

# 항상 Prod 환경
ENV_NAME: prod
ENV_DIR: envs/prod
```

## 주요 변경 사항

### 1. terraform-apply.yml
- **트리거**: `main` 브랜치 푸시 시에만 실행
- **환경**: 항상 `prod` 환경
- **Secrets**: `TFVARS_PROD` 사용
- **Environment**: GitHub Environment `prod` 보호 규칙 적용

### 2. terraform-plan.yml
- **트리거**: `main` 브랜치로의 PR 생성 시에만 실행
- **환경**: 항상 `prod` 환경
- **Secrets**: `TFVARS_PROD` 사용

## 배포 플로우

### Prod 환경 배포

```
1. feature 브랜치에서 작업
   ↓
2. main 브랜치로 PR 생성
   ↓
3. terraform-plan 자동 실행 (Prod Plan)
   ↓
4. PR 리뷰 및 승인
   ↓
5. PR 머지 (main 브랜치)
   ↓
6. terraform-apply 자동 실행 (Prod Apply)
   ↓
7. GitHub Environment 승인 (설정된 경우)
   ↓
8. Prod 환경 배포 완료
```

### Dev 환경 배포 (필요한 경우)

Dev 환경을 배포하려면 다음 방법 중 하나를 사용:

#### 방법 1: 로컬에서 수동 배포
```bash
cd envs/dev
terraform init
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

#### 방법 2: 별도 워크플로우 생성
`.github/workflows/terraform-dev-manual.yml` 파일 생성:
```yaml
name: terraform-dev-manual

on:
  workflow_dispatch:  # 수동 트리거

env:
  AWS_REGION: ap-northeast-2
  ENV_NAME: dev
  ENV_DIR: envs/dev

jobs:
  apply:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      # ... (동일한 단계)
```

## 필요한 GitHub Secrets

### Prod 환경
- `AWS_ROLE_ARN` (또는 `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`)
- `TFVARS_PROD`
- `DISCORD_WEBHOOK_URL` (선택적)

### Dev 환경 (수동 배포 시)
- `TFVARS_DEV` (필요한 경우)

## GitHub Environment 설정 (권장)

Prod 환경 보호를 위해 GitHub Environment 설정:

1. GitHub 저장소 → **Settings** → **Environments**
2. **New environment** 클릭
3. 이름: `prod`
4. **Protection rules** 설정:
   - ✅ **Required reviewers**: 승인자 지정 (1-6명)
   - ✅ **Wait timer**: 대기 시간 설정 (선택적)
   - ✅ **Deployment branches**: `main` 브랜치만 허용

### Environment 보호 규칙 효과

```
PR 머지 → terraform-apply 실행 → 승인 대기 → 승인 후 배포
```

승인자가 **Review deployments** 버튼을 클릭하고 승인해야 배포가 진행됩니다.

## 장점

### 1. 안전성 향상
- Prod 환경만 자동 배포되므로 실수로 Dev 배포하는 일 방지
- GitHub Environment 보호 규칙으로 추가 승인 단계

### 2. 명확한 배포 플로우
- `main` 브랜치 = Prod 환경
- 혼란 없이 명확한 배포 대상

### 3. 비용 절감
- Dev 환경 자동 배포 제거로 불필요한 리소스 생성 방지
- 필요할 때만 수동으로 Dev 배포

## 주의사항

### 1. Dev 환경 테스트
Dev 환경에서 테스트가 필요한 경우:
- 로컬에서 `terraform plan` 실행하여 검증
- 또는 별도 수동 워크플로우 사용

### 2. 롤백
문제 발생 시:
```bash
# GitHub에서 revert
git revert HEAD
git push origin main

# 또는 로컬에서 destroy
cd envs/prod
terraform destroy
```

### 3. 긴급 배포
긴급 상황 시:
- PR 없이 직접 `main` 브랜치에 푸시 가능 (권장하지 않음)
- 또는 PR을 빠르게 리뷰하고 머지

## 테스트

워크플로우 변경 후 테스트:

1. **Plan 테스트**:
   ```bash
   # feature 브랜치에서 main으로 PR 생성
   gh pr create --base main --head feature/test --title "test: Workflow test"
   
   # Actions 탭에서 terraform-plan 실행 확인
   ```

2. **Apply 테스트** (주의!):
   ```bash
   # PR 머지
   gh pr merge --squash
   
   # Actions 탭에서 terraform-apply 실행 확인
   # Environment 승인 필요 시 승인
   ```

## 참고 문서

- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)

---

**변경일**: 2026-02-09
**변경자**: DevOps Team
