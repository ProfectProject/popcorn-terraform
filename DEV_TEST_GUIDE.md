# Dev 환경 테스트 가이드

## 목적

Prod 배포 전에 Dev 환경에서 인프라를 테스트하고 검증합니다.

## 현재 워크플로우 구조

```yaml
# develop 브랜치 → Dev 환경
# main 브랜치 → Prod 환경

develop 브랜치 푸시 → terraform-apply (Dev)
main 브랜치 푸시 → terraform-apply (Prod)
```

## Dev 환경 배포 절차

### 1단계: develop 브랜치 생성 (필요한 경우)

```bash
# 현재 브랜치 확인
git branch

# develop 브랜치가 없으면 생성
git checkout -b develop

# 또는 기존 develop 브랜치로 전환
git checkout develop
```

### 2단계: GitHub Secrets 설정 확인

Dev 환경 배포를 위해 다음 Secrets가 필요합니다:

```bash
# GitHub CLI로 확인
gh secret list

# 필요한 Secrets:
# - AWS_ROLE_ARN (또는 AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY)
# - TFVARS_DEV
# - DISCORD_WEBHOOK_URL (선택적)
```

**TFVARS_DEV 설정**:
```bash
# envs/dev/terraform.tfvars 내용을 GitHub Secret으로 등록
gh secret set TFVARS_DEV < envs/dev/terraform.tfvars

# 또는 GitHub 웹 UI에서:
# Settings → Secrets → New repository secret
# Name: TFVARS_DEV
# Value: terraform.tfvars 파일 내용 전체
```

### 3단계: Dev 환경 배포

#### 방법 1: PR을 통한 배포 (권장)

```bash
# feature 브랜치에서 작업
git checkout -b feature/test-dev-deployment

# 변경사항 커밋
git add .
git commit -m "test: Dev environment deployment test"

# 푸시
git push origin feature/test-dev-deployment

# develop 브랜치로 PR 생성
gh pr create \
  --base develop \
  --head feature/test-dev-deployment \
  --title "test: Dev environment deployment" \
  --body "Dev 환경 배포 테스트"

# PR에서 terraform-plan 결과 확인
# PR 머지 → terraform-apply 자동 실행
gh pr merge --squash
```

#### 방법 2: 직접 develop 브랜치에 푸시

```bash
# develop 브랜치로 전환
git checkout develop

# 변경사항 커밋
git add .
git commit -m "test: Dev environment deployment test"

# 푸시 → terraform-apply 자동 실행
git push origin develop
```

### 4단계: 배포 모니터링

```bash
# GitHub Actions 로그 확인
# https://github.com/YOUR_ORG/popcorn-terraform-feature/actions

# 또는 CLI로 확인
gh run list --workflow=terraform-apply
gh run view --log
```

**예상 소요 시간**: 20-30분

**주요 단계**:
1. ⏱️ VPC 생성 (2-3분)
2. ⏱️ EKS 클러스터 생성 (10-15분)
3. ⏱️ RDS 생성 (5-10분)
4. ⏱️ ElastiCache 생성 (3-5분)
5. ⏱️ ALB 및 기타 리소스 (2-3분)

### 5단계: 배포 확인

#### AWS CLI로 확인

```bash
# VPC 확인
aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=dev" \
  --region ap-northeast-2

# EKS 클러스터 확인
aws eks describe-cluster \
  --name goorm-popcorn-dev \
  --region ap-northeast-2

# RDS 확인
aws rds describe-db-instances \
  --db-instance-identifier goorm-popcorn-dev \
  --region ap-northeast-2

# ElastiCache 확인
aws elasticache describe-replication-groups \
  --replication-group-id goorm-popcorn-cache-dev \
  --region ap-northeast-2

# ALB 확인
aws elbv2 describe-load-balancers \
  --region ap-northeast-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `goorm-popcorn-dev`)]'
```

#### EKS 클러스터 접근

```bash
# kubeconfig 설정
aws eks update-kubeconfig \
  --name goorm-popcorn-dev \
  --region ap-northeast-2

# 노드 확인
kubectl get nodes

# 예상 결과: 2개 노드 (Ready 상태)
```

#### 도메인 확인

```bash
# DNS 레코드 확인
nslookup dev.goormpopcorn.shop
nslookup api-dev.goormpopcorn.shop
nslookup kafka-dev.goormpopcorn.shop
```

### 6단계: 테스트 및 검증

#### 인프라 검증 스크립트 실행

```bash
# 로컬에서 검증 스크립트 실행
cd /Users/beom/IdeaProjects/popcorn-terraform-feature

# 모든 속성 검증
ENV=dev ./scripts/validate-properties.sh

# 개별 검증
./scripts/validate-vpc-config.sh
./scripts/validate-eks-config.sh
./scripts/validate-rds-config.sh
./scripts/validate-security-groups.sh
```

#### 애플리케이션 배포 테스트

```bash
# EKS에 간단한 테스트 Pod 배포
kubectl run test-nginx --image=nginx --port=80

# Pod 상태 확인
kubectl get pods

# 정리
kubectl delete pod test-nginx
```

## Dev 환경 제거 (테스트 완료 후)

### 방법 1: GitHub Actions로 제거 (권장)

별도의 destroy 워크플로우 생성:

```bash
# .github/workflows/terraform-destroy-dev.yml 생성
cat > .github/workflows/terraform-destroy-dev.yml <<'EOF'
name: terraform-destroy-dev

on:
  workflow_dispatch:  # 수동 트리거만

permissions:
  contents: read
  id-token: write

env:
  AWS_REGION: ap-northeast-2
  ENV_NAME: dev
  ENV_DIR: envs/dev

jobs:
  destroy:
    runs-on: ubuntu-latest
    environment: dev-destroy  # 별도 Environment로 보호
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6

      - name: Prepare terraform.tfvars
        env:
          TFVARS_CONTENT: ${{ secrets.TFVARS_DEV }}
        run: |
          set -euo pipefail
          if [[ -n "${TFVARS_CONTENT:-}" ]]; then
            printf "%s" "$TFVARS_CONTENT" > "${ENV_DIR}/terraform.tfvars"
          fi

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform init
        run: terraform init
        working-directory: ${{ env.ENV_DIR }}

      - name: Terraform destroy
        run: terraform destroy -auto-approve
        working-directory: ${{ env.ENV_DIR }}

      - name: Notify Discord
        if: always()
        env:
          DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
          JOB_STATUS: ${{ job.status }}
        run: |
          if [[ -z "$DISCORD_WEBHOOK_URL" ]]; then
            exit 0
          fi

          if [[ "$JOB_STATUS" == "success" ]]; then
            emoji="🗑️"
            status_label="제거 완료"
          else
            emoji="❌"
            status_label="제거 실패"
          fi

          payload=$(jq -n \
            --arg emoji "$emoji" \
            --arg status "$status_label" \
            '{
              "content": "\($emoji) Dev 환경 \($status)"
            }')

          curl -H "Content-Type: application/json" \
            -X POST -d "$payload" \
            "$DISCORD_WEBHOOK_URL"
EOF

# 커밋 및 푸시
git add .github/workflows/terraform-destroy-dev.yml
git commit -m "feat: Add Dev environment destroy workflow"
git push origin develop

# GitHub Actions에서 수동 실행
# Actions → terraform-destroy-dev → Run workflow
```

### 방법 2: 로컬에서 제거

```bash
cd envs/dev

# AWS 자격증명 확인
aws sts get-caller-identity

# Terraform 초기화
terraform init

# Destroy 실행
terraform destroy

# 확인 프롬프트에서 'yes' 입력
```

**예상 소요 시간**: 15-20분

**주요 단계**:
1. ⏱️ ALB 제거 (2-3분)
2. ⏱️ EKS 클러스터 제거 (5-10분)
3. ⏱️ RDS 제거 (5-7분)
4. ⏱️ ElastiCache 제거 (2-3분)
5. ⏱️ VPC 및 기타 리소스 (2-3분)

### 방법 3: 특정 리소스만 제거

```bash
cd envs/dev

# EKS만 제거
terraform destroy -target=module.eks

# RDS만 제거
terraform destroy -target=module.rds

# 전체 제거
terraform destroy
```

## 비용 관리

### Dev 환경 예상 비용

**시간당 비용**: ~$0.33/시간
**일일 비용**: ~$7.92/일
**월간 비용**: ~$235/월

**주요 비용 항목**:
- NAT Gateway: ~$0.045/시간
- EKS Control Plane: ~$0.10/시간
- EKS Nodes (t3.medium x 2): ~$0.083/시간
- RDS (db.t4g.micro): ~$0.021/시간
- ElastiCache (cache.t4g.micro): ~$0.017/시간
- ALB x 2: ~$0.045/시간

### 비용 절감 팁

1. **테스트 후 즉시 제거**
   ```bash
   # 테스트 완료 후 바로 destroy
   terraform destroy
   ```

2. **업무 시간에만 운영**
   ```bash
   # 오전 9시 배포
   # 오후 6시 제거
   # 일일 비용: ~$2.64 (9시간)
   ```

3. **주말 제거**
   ```bash
   # 금요일 저녁 제거
   # 월요일 아침 재배포
   ```

## 트러블슈팅

### 1. 배포 실패

**증상**: terraform-apply 워크플로우 실패

**해결**:
```bash
# GitHub Actions 로그 확인
gh run view --log

# 로컬에서 Plan 실행
cd envs/dev
terraform init
terraform plan

# 문제 수정 후 재배포
git add .
git commit -m "fix: Resolve deployment issue"
git push origin develop
```

### 2. State 잠금 오류

**증상**: "Error acquiring the state lock"

**해결**:
```bash
# 로컬에서 잠금 해제
cd envs/dev
terraform force-unlock LOCK_ID

# 또는 DynamoDB에서 직접 제거
aws dynamodb delete-item \
  --table-name goorm-popcorn-tfstate-lock \
  --key '{"LockID":{"S":"goorm-popcorn-tfstate/dev/terraform.tfstate-md5"}}' \
  --region ap-northeast-2
```

### 3. 리소스 제거 실패

**증상**: terraform destroy 실패

**해결**:
```bash
# 의존성 순서대로 제거
terraform destroy -target=module.eks
terraform destroy -target=module.rds
terraform destroy -target=module.elasticache
terraform destroy -target=module.vpc

# 또는 AWS 콘솔에서 수동 제거
```

## 체크리스트

### 배포 전
- [ ] GitHub Secrets 설정 완료 (TFVARS_DEV, AWS_ROLE_ARN)
- [ ] develop 브랜치 생성 완료
- [ ] terraform.tfvars 파일 검증 완료
- [ ] 비용 예산 확인 완료

### 배포 중
- [ ] GitHub Actions 워크플로우 실행 확인
- [ ] 각 단계별 로그 모니터링
- [ ] 에러 발생 시 즉시 대응

### 배포 후
- [ ] 모든 리소스 생성 확인
- [ ] EKS 클러스터 접근 확인
- [ ] 검증 스크립트 실행 완료
- [ ] 애플리케이션 배포 테스트 완료

### 제거 전
- [ ] 중요 데이터 백업 완료 (필요한 경우)
- [ ] 제거할 리소스 목록 확인
- [ ] 팀원에게 제거 예정 공지

### 제거 후
- [ ] 모든 리소스 제거 확인
- [ ] 비용 발생 중단 확인
- [ ] State 파일 정리 확인

## 다음 단계

Dev 환경 테스트가 성공적으로 완료되면:

1. **Prod 환경 배포 준비**
   - TFVARS_PROD Secret 설정
   - main 브랜치로 PR 생성
   - Prod 배포 가이드 참조

2. **Dev 환경 제거**
   - terraform destroy 실행
   - 비용 발생 중단 확인

3. **Prod 환경 배포**
   - main 브랜치로 PR 머지
   - terraform-apply 실행
   - 배포 모니터링

---

**작성일**: 2026-02-09
**작성자**: DevOps Team
