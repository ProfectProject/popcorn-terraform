# Prod 환경 배포 가이드

## 현재 상태

- **현재 브랜치**: `feature/eks`
- **배포 방식**: GitHub Actions
- **대상 환경**: Production (main 브랜치)

## 배포 전 체크리스트

### 1. GitHub Secrets 확인

다음 Secrets가 GitHub 저장소에 설정되어 있어야 합니다:

```bash
# GitHub CLI로 확인
gh secret list

# 필수 Secrets:
# - AWS_ROLE_ARN (OIDC 방식) 또는 AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY
# - TFVARS_PROD (Prod 환경 변수)
# - DISCORD_WEBHOOK_URL (선택적)
```

**Secrets 설정 방법**:
1. GitHub 저장소 페이지 → **Settings** → **Secrets and variables** → **Actions**
2. **New repository secret** 클릭
3. 다음 Secrets 추가:
   - `AWS_ROLE_ARN`: OIDC 역할 ARN (권장)
   - `TFVARS_PROD`: Prod 환경의 terraform.tfvars 내용 전체
   - `DISCORD_WEBHOOK_URL`: Discord 알림용 (선택적)

### 2. Prod 환경 변수 준비

`envs/prod/terraform.tfvars` 파일을 GitHub Secrets에 등록해야 합니다:

```bash
# 현재 terraform.tfvars 내용 확인
cat envs/prod/terraform.tfvars

# 중요: 다음 항목들을 실제 값으로 변경했는지 확인
# - whitelist_ips: 실제 사무실/VPN IP로 변경
# - rds_master_password: Secrets Manager에서 관리 (자동 생성)
```

**GitHub Secret으로 등록**:
```bash
# GitHub CLI 사용
gh secret set TFVARS_PROD < envs/prod/terraform.tfvars

# 또는 웹 UI에서 수동 등록
# Settings → Secrets → New repository secret
# Name: TFVARS_PROD
# Value: terraform.tfvars 파일 내용 전체 복사
```

### 3. AWS OIDC 설정 (권장)

GitHub Actions에서 AWS 자격증명을 안전하게 사용하기 위해 OIDC 방식을 권장합니다.

**OIDC Identity Provider 생성**:
```bash
# AWS 콘솔에서 IAM → Identity providers → Add provider
# Provider type: OpenID Connect
# Provider URL: https://token.actions.githubusercontent.com
# Audience: sts.amazonaws.com
```

**IAM Role 생성**:
```bash
# Trust policy 예시
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::375896310755:oidc-provider/token.actions.githubusercontent.com"
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

# 권한 정책: AdministratorAccess 또는 필요한 권한만
```

### 4. 변경사항 커밋 및 푸시

```bash
# 현재 디렉터리 확인
pwd  # /Users/beom/IdeaProjects/popcorn-terraform-feature

# 변경사항 스테이징
git add .

# 커밋
git commit -m "feat: Add Prod environment configuration and deployment workflows"

# 푸시
git push origin feature/eks
```

## 배포 절차

### Step 1: Pull Request 생성

```bash
# GitHub CLI 사용
gh pr create \
  --base main \
  --head feature/eks \
  --title "feat: Production environment deployment" \
  --body "## 변경 사항

- Prod 환경 Terraform 설정 추가
- GitHub Actions 워크플로우 설정
- Bootstrap S3 백엔드 통합 (단일 버킷)
- 모듈 업데이트 및 검증 스크립트 추가

## 배포 계획

- **환경**: Production
- **리전**: ap-northeast-2 (서울)
- **주요 리소스**:
  - VPC (Multi-AZ)
  - EKS 1.35
  - RDS PostgreSQL 18.1 (Multi-AZ)
  - ElastiCache Valkey (Primary + Replica)
  - ALB x 2

## 체크리스트

- [x] Terraform validate 통과
- [x] 검증 스크립트 작성
- [x] 문서 작성
- [ ] GitHub Secrets 설정
- [ ] Terraform Plan 검토
- [ ] 팀 리뷰 완료"
```

**또는 GitHub 웹 UI 사용**:
1. GitHub 저장소 페이지로 이동
2. **Pull requests** → **New pull request**
3. Base: `main`, Compare: `feature/eks`
4. PR 제목 및 설명 작성
5. **Create pull request** 클릭

### Step 2: Terraform Plan 자동 실행 및 검토

PR 생성 후 자동으로 `terraform-plan` 워크플로우가 실행됩니다:

1. **Actions** 탭에서 워크플로우 실행 상태 확인
2. PR 페이지에서 Plan 결과 코멘트 확인
3. **중요**: Plan 결과를 꼼꼼히 검토
   - 생성될 리소스 확인
   - 변경될 리소스 확인
   - 삭제될 리소스 확인 (없어야 함)
   - 예상 비용 확인

**Plan 검토 포인트**:
```
Plan: XX to add, 0 to change, 0 to destroy.

주요 확인 사항:
- VPC 및 서브넷 (Multi-AZ)
- NAT Gateway x 2
- EKS 클러스터 및 노드 그룹
- RDS (Multi-AZ, db.t4g.small)
- ElastiCache (2 nodes)
- ALB x 2
- Security Groups
- IAM Roles
- Route53 레코드
- CloudWatch 대시보드 및 알람
```

### Step 3: 팀 리뷰 및 승인

1. 팀원에게 PR 리뷰 요청
2. Plan 결과를 함께 검토
3. 다음 사항 확인:
   - [ ] 모든 리소스가 예상대로 생성되는가?
   - [ ] Multi-AZ 설정이 올바른가?
   - [ ] 보안 그룹 규칙이 적절한가?
   - [ ] 비용이 예산 내인가?
   - [ ] 백업 및 모니터링 설정이 있는가?

### Step 4: PR 머지

리뷰 승인 후:

```bash
# GitHub CLI 사용
gh pr merge --squash

# 또는 웹 UI에서 "Squash and merge" 클릭
```

### Step 5: Terraform Apply 자동 실행

PR 머지 후 `terraform-apply` 워크플로우가 자동으로 실행됩니다:

1. **Actions** 탭에서 Apply 워크플로우 실행 확인
2. **Environment: prod** 환경 보호 규칙에 따라 수동 승인 필요할 수 있음
3. **Review deployments** 버튼 클릭
4. 변경 사항 최종 검토
5. **Approve and deploy** 클릭

**Apply 진행 상황 모니터링**:
```
예상 소요 시간: 20-30분

주요 단계:
1. VPC 생성 (2-3분)
2. EKS 클러스터 생성 (10-15분)
3. RDS 생성 (5-10분)
4. ElastiCache 생성 (3-5분)
5. ALB 및 기타 리소스 (2-3분)
```

### Step 6: 배포 확인

Apply 완료 후 다음을 확인합니다:

#### 6.1 Terraform Outputs 확인

```bash
# GitHub Actions 로그에서 outputs 확인
# 또는 로컬에서 확인 (AWS 자격증명 필요)
cd envs/prod
terraform init
terraform output
```

#### 6.2 AWS 콘솔 확인

**VPC**:
```bash
# AWS CLI로 확인
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=goorm-popcorn" \
  --region ap-northeast-2
```

**EKS 클러스터**:
```bash
# 클러스터 상태 확인
aws eks describe-cluster \
  --name goorm-popcorn-prod \
  --region ap-northeast-2

# kubeconfig 설정
aws eks update-kubeconfig \
  --name goorm-popcorn-prod \
  --region ap-northeast-2

# 노드 확인
kubectl get nodes
```

**RDS**:
```bash
# RDS 인스턴스 확인
aws rds describe-db-instances \
  --db-instance-identifier goorm-popcorn-prod \
  --region ap-northeast-2
```

**ElastiCache**:
```bash
# ElastiCache 클러스터 확인
aws elasticache describe-replication-groups \
  --replication-group-id goorm-popcorn-cache-prod \
  --region ap-northeast-2
```

**ALB**:
```bash
# ALB 확인
aws elbv2 describe-load-balancers \
  --region ap-northeast-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `goorm-popcorn-prod`)]'
```

#### 6.3 도메인 확인

```bash
# DNS 레코드 확인
nslookup goormpopcorn.shop
nslookup api.goormpopcorn.shop
nslookup kafka.goormpopcorn.shop
nslookup argocd.goormpopcorn.shop
nslookup grafana.goormpopcorn.shop
```

#### 6.4 모니터링 확인

```bash
# CloudWatch 대시보드 URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#dashboards:"

# CloudWatch 알람 확인
aws cloudwatch describe-alarms \
  --alarm-name-prefix goorm-popcorn-prod \
  --region ap-northeast-2
```

## 배포 후 작업

### 1. 애플리케이션 배포 준비

```bash
# EKS 클러스터에 필수 컴포넌트 설치
# 1. AWS Load Balancer Controller
# 2. EBS CSI Driver (이미 활성화됨)
# 3. Cluster Autoscaler 또는 Karpenter
# 4. Metrics Server
# 5. ArgoCD

# popcorn_deploy 저장소로 이동하여 Helm 차트 배포
```

### 2. 데이터베이스 초기화

```bash
# RDS 엔드포인트 확인
terraform output rds_endpoint

# 데이터베이스 연결 및 스키마 생성
# (애플리케이션 배포 시 자동으로 수행될 수 있음)
```

### 3. 모니터링 설정

```bash
# Grafana 대시보드 설정
# Prometheus 메트릭 수집 설정
# 알람 테스트
```

### 4. 보안 검토

```bash
# Security Group 규칙 재검토
# IAM 정책 최소화
# Secrets Manager 확인
# 암호화 설정 확인
```

## 롤백 절차

배포 중 문제 발생 시:

### 1. 즉시 롤백

```bash
# GitHub에서 이전 커밋으로 revert
git revert HEAD
git push origin main

# 또는 PR을 통해 롤백
gh pr create --base main --head revert-branch --title "revert: Rollback prod deployment"
```

### 2. 특정 리소스만 롤백

```bash
# 로컬에서 특정 리소스 제거
cd envs/prod
terraform destroy -target=module.eks
```

### 3. 전체 롤백

```bash
# 모든 리소스 제거 (주의!)
cd envs/prod
terraform destroy
```

## 예상 비용

### Prod 환경 월간 비용

- **VPC (NAT Gateway x 2)**: ~$64
- **EKS Control Plane**: ~$73
- **EKS Nodes (t3.medium x 6)**: ~$180
- **RDS (db.t4g.small, Multi-AZ)**: ~$60
- **ElastiCache (cache.t4g.small x 2)**: ~$48
- **ALB x 2**: ~$32
- **Route53**: ~$1
- **CloudWatch**: ~$20
- **데이터 전송**: ~$20

**총 예상 비용**: ~$498/월

### 비용 최적화 옵션

1. **EKS Nodes**: Karpenter Spot Instance 활성화 시 ~50% 절감
2. **RDS**: Reserved Instance 구매 시 ~40% 절감
3. **ElastiCache**: Reserved Nodes 구매 시 ~40% 절감
4. **NAT Gateway**: 단일 NAT Gateway 사용 시 ~$32 절감 (고가용성 감소)

## 트러블슈팅

### 문제 1: GitHub Actions 워크플로우 실패

**증상**: Plan 또는 Apply 단계에서 실패

**해결**:
1. Actions 로그 확인
2. AWS 자격증명 확인
3. Terraform 구문 오류 확인
4. AWS 리소스 제한 확인

### 문제 2: State 잠금 오류

**증상**: "Error acquiring the state lock"

**해결**:
```bash
# 로컬에서 잠금 해제
cd envs/prod
terraform force-unlock LOCK_ID
```

### 문제 3: 리소스 생성 실패

**증상**: 특정 리소스 생성 중 오류

**해결**:
1. AWS 콘솔에서 리소스 상태 확인
2. CloudWatch Logs 확인
3. 필요시 수동으로 리소스 정리
4. Terraform 재실행

## 지원

문제가 발생하면:
- **Slack**: #devops-support
- **Email**: devops@goorm.io
- **문서**: `docs/` 디렉터리 참조

## 참고 문서

- [배포 가이드](docs/DEPLOYMENT_GUIDE.md)
- [GitHub Actions 가이드](docs/GITHUB_ACTIONS_GUIDE.md)
- [배포 전 체크리스트](docs/PRE_DEPLOYMENT_CHECKLIST.md)

---

**작성일**: 2026-02-09
**작성자**: DevOps Team
**버전**: 1.0.0
