# GitHub Actions 워크플로우 가이드

## 개요

이 문서는 Terraform 인프라 배포를 위한 GitHub Actions 워크플로우 사용 방법을 설명합니다.

## 워크플로우 구조

### Dev 환경 워크플로우

**파일**: `.github/workflows/terraform-dev.yml`

**트리거**:
- PR 생성/업데이트 시: `terraform plan` 실행
- PR 머지 시 (main 브랜치): `terraform apply` 실행

**주요 단계**:
1. Terraform 설정
2. Terraform 초기화
3. Terraform Plan 실행
4. Plan 결과를 PR 코멘트로 표시
5. PR 머지 시 Apply 실행

### Prod 환경 워크플로우

**파일**: `.github/workflows/terraform-prod.yml`

**트리거**:
- PR 생성/업데이트 시: `terraform plan` 실행
- PR 머지 시 (main 브랜치): 수동 승인 후 `terraform apply` 실행

**주요 단계**:
1. Terraform 설정
2. Terraform 초기화
3. Terraform Plan 실행
4. Plan 결과를 PR 코멘트로 표시
5. 수동 승인 대기
6. 승인 후 Apply 실행

## GitHub Secrets 설정

### 필수 Secrets

워크플로우 실행을 위해 다음 Secrets를 설정해야 합니다:

1. **AWS_ACCESS_KEY_ID**: AWS 액세스 키 ID
2. **AWS_SECRET_ACCESS_KEY**: AWS 시크릿 액세스 키
3. **SLACK_WEBHOOK_URL**: Slack 알림용 Webhook URL (선택적)

### Secrets 설정 방법

1. GitHub 저장소 페이지로 이동
2. **Settings** > **Secrets and variables** > **Actions** 클릭
3. **New repository secret** 클릭
4. Secret 이름과 값 입력
5. **Add secret** 클릭

## PR 생성 및 배포 절차

### 1. 브랜치 생성

```bash
# 새 브랜치 생성
git checkout -b feature/update-eks-version

# 변경 사항 커밋
git add envs/dev/terraform.tfvars
git commit -m "feat: Update EKS version to 1.35"
git push origin feature/update-eks-version
```

### 2. PR 생성

1. GitHub 저장소 페이지로 이동
2. **Pull requests** > **New pull request** 클릭
3. Base 브랜치: `main`, Compare 브랜치: `feature/update-eks-version` 선택
4. PR 제목 및 설명 작성
5. **Create pull request** 클릭

### 3. Terraform Plan 확인

PR 생성 후 자동으로 GitHub Actions 워크플로우가 실행됩니다:

1. **Actions** 탭에서 워크플로우 실행 상태 확인
2. PR 페이지에서 Plan 결과 코멘트 확인
3. Plan 결과를 검토하여 예상대로 변경되는지 확인

**Plan 코멘트 예시**:

```
#### Terraform Plan 📖 `success`
#### Environment: dev

<details><summary>Show Plan</summary>

```hcl
Terraform will perform the following actions:

  # module.eks.aws_eks_cluster.main will be updated in-place
  ~ resource "aws_eks_cluster" "main" {
      ~ version = "1.34" -> "1.35"
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

</details>
```

### 4. PR 리뷰 및 승인

1. 팀원에게 PR 리뷰 요청
2. Plan 결과를 함께 검토
3. 승인 후 **Merge pull request** 클릭

### 5. Terraform Apply 실행

#### Dev 환경

PR 머지 후 자동으로 `terraform apply`가 실행됩니다:

1. **Actions** 탭에서 Apply 워크플로우 실행 상태 확인
2. Apply 완료 후 Slack 알림 확인 (설정한 경우)
3. AWS 콘솔에서 리소스 변경 확인

#### Prod 환경

PR 머지 후 수동 승인이 필요합니다:

1. **Actions** 탭에서 워크플로우 실행 확인
2. **Review deployments** 버튼 클릭
3. 변경 사항 검토 후 **Approve and deploy** 클릭
4. Apply 완료 후 Slack 알림 확인
5. AWS 콘솔에서 리소스 변경 확인

## 워크플로우 동시 실행 방지

### Concurrency 설정

각 환경별로 동시 실행을 방지하는 concurrency 그룹이 설정되어 있습니다:

```yaml
concurrency:
  group: terraform-dev
  cancel-in-progress: false
```

이 설정으로 인해:
- 동일 환경에 대한 워크플로우가 이미 실행 중이면 새 워크플로우는 대기
- 이전 워크플로우가 완료되면 자동으로 다음 워크플로우 실행

### 대기 중인 워크플로우 확인

1. **Actions** 탭으로 이동
2. 대기 중인 워크플로우는 "Queued" 상태로 표시
3. 이전 워크플로우 완료 후 자동으로 실행

## 에러 대응 방법

### 1. Terraform Plan 실패

**증상**: PR 코멘트에 Plan 실패 메시지 표시

**원인**:
- Terraform 구문 오류
- 변수 값 오류
- AWS 리소스 제한 초과

**해결 방법**:
1. Actions 탭에서 상세 로그 확인
2. 오류 메시지 분석
3. 코드 수정 후 다시 푸시
4. 워크플로우 자동 재실행

### 2. Terraform Apply 실패

**증상**: Apply 단계에서 워크플로우 실패

**원인**:
- AWS 리소스 생성 실패
- 타임아웃
- 권한 부족

**해결 방법**:
1. Actions 탭에서 상세 로그 확인
2. AWS 콘솔에서 리소스 상태 확인
3. 필요시 수동으로 리소스 정리
4. 코드 수정 후 다시 배포

### 3. State 잠금 오류

**증상**: "Error acquiring the state lock" 메시지

**원인**:
- 이전 워크플로우가 비정상 종료
- DynamoDB 잠금이 해제되지 않음

**해결 방법**:
```bash
# 로컬에서 잠금 해제
cd envs/dev  # 또는 envs/prod
terraform force-unlock LOCK_ID
```

### 4. AWS 자격증명 오류

**증상**: "Error: error configuring Terraform AWS Provider"

**원인**:
- GitHub Secrets가 설정되지 않음
- AWS 자격증명이 만료됨
- IAM 권한 부족

**해결 방법**:
1. GitHub Secrets 확인 및 업데이트
2. AWS IAM 권한 확인
3. 필요시 새 액세스 키 생성

## 워크플로우 커스터마이징

### Slack 알림 추가

```yaml
- name: Slack Notification
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Terraform ${{ steps.plan.outcome }} for ${{ github.event.pull_request.title }}'
    webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 추가 검증 단계

```yaml
- name: Run Property Validation
  run: |
    ENV=${{ matrix.environment }} ./scripts/validate-properties.sh
```

### 비용 추정 추가

```yaml
- name: Terraform Cost Estimation
  uses: terraform-cost-estimation/action@v1
  with:
    terraform_plan_file: plan.tfplan
```

## 모범 사례

### 1. PR 크기 최소화

- 한 번에 하나의 변경 사항만 포함
- 큰 변경은 여러 PR로 분할
- 리뷰 및 롤백이 용이

### 2. Plan 결과 검토

- 모든 변경 사항을 꼼꼼히 검토
- 예상치 못한 변경이 있는지 확인
- 리소스 삭제는 특히 주의

### 3. 테스트 환경 우선

- Dev 환경에서 먼저 테스트
- 문제 없으면 Prod 환경에 적용
- 점진적 배포

### 4. 롤백 계획

- 변경 전 현재 상태 백업
- 롤백 절차 문서화
- 긴급 롤백 시나리오 준비

### 5. 모니터링

- Apply 후 CloudWatch 메트릭 확인
- 알람 발생 여부 확인
- 애플리케이션 정상 동작 확인

## 트러블슈팅 체크리스트

- [ ] GitHub Secrets가 올바르게 설정되어 있는가?
- [ ] AWS 자격증명이 유효한가?
- [ ] IAM 권한이 충분한가?
- [ ] S3 백엔드 버킷이 존재하는가?
- [ ] DynamoDB 테이블이 존재하는가?
- [ ] Terraform 버전이 호환되는가?
- [ ] 변수 값이 올바른가?
- [ ] 리소스 제한에 도달하지 않았는가?

## 참고 자료

- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://github.com/hashicorp/setup-terraform)
- [AWS GitHub Actions](https://github.com/aws-actions)

## 지원

문제가 발생하면 DevOps 팀에 문의하세요:
- Slack: #devops-support
- Email: devops@goorm.io

