# Prod 배포 체크리스트

## 배포 전 필수 확인 사항

### ✅ 1. GitHub Secrets 설정

- [ ] **AWS_ROLE_ARN** 설정 완료 (OIDC 방식 권장)
  - 또는 **AWS_ACCESS_KEY_ID** + **AWS_SECRET_ACCESS_KEY**
- [ ] **TFVARS_PROD** 설정 완료
  - `envs/prod/terraform.tfvars` 파일 내용 전체
- [ ] **DISCORD_WEBHOOK_URL** 설정 (선택적)

**확인 방법**:
```bash
gh secret list
```

### ✅ 2. Prod 환경 변수 검증

- [ ] `whitelist_ips`: 실제 사무실/VPN IP로 변경
- [ ] `eks_node_desired_size`: 적절한 노드 수 설정 (현재: 6)
- [ ] `rds_instance_class`: 적절한 인스턴스 타입 (현재: db.t4g.small)
- [ ] `elasticache_node_type`: 적절한 노드 타입 (현재: cache.t4g.small)
- [ ] Multi-AZ 설정 확인:
  - `single_nat_gateway = false`
  - `elasticache_automatic_failover = true`
  - `elasticache_multi_az_enabled = true`

**확인 방법**:
```bash
cat envs/prod/terraform.tfvars
```

### ✅ 3. AWS 리소스 사전 확인

- [ ] S3 버킷 존재: `goorm-popcorn-tfstate`
- [ ] DynamoDB 테이블 존재: `goorm-popcorn-tfstate-lock`
- [ ] Route53 호스팅 존: `goormpopcorn.shop`
- [ ] ACM 인증서 상태: `ISSUED`
- [ ] ECR 리포지토리 8개 생성 완료

**확인 방법**:
```bash
./scripts/check-aws-resources.sh
```

### ✅ 4. Git 상태 확인

- [ ] 모든 변경사항 커밋 완료
- [ ] 현재 브랜치: `feature/eks`
- [ ] 원격 저장소에 푸시 완료

**확인 방법**:
```bash
git status
git log --oneline -5
```

### ✅ 5. 비용 확인

예상 월간 비용: **~$498**

주요 비용 항목:
- VPC (NAT Gateway x 2): $64
- EKS (Control Plane + Nodes): $253
- RDS (Multi-AZ): $60
- ElastiCache (2 nodes): $48
- ALB x 2: $32
- 기타: $41

- [ ] 예산 승인 완료
- [ ] 비용 알람 설정 계획 수립

### ✅ 6. 백업 및 롤백 계획

- [ ] 현재 인프라 상태 문서화 (해당 없음 - 신규 배포)
- [ ] 롤백 절차 숙지
- [ ] 긴급 연락망 확인

## 배포 단계

### Step 1: 변경사항 커밋 및 푸시

```bash
# 현재 디렉터리 확인
cd /Users/beom/IdeaProjects/popcorn-terraform-feature

# 변경사항 확인
git status

# 스테이징
git add .

# 커밋
git commit -m "feat: Add Prod environment configuration

- Prod 환경 Terraform 설정 추가
- Multi-AZ 구성 (고가용성)
- GitHub Actions 워크플로우 설정
- Bootstrap S3 백엔드 통합
- 검증 스크립트 및 문서 추가"

# 푸시
git push origin feature/eks
```

**완료 확인**: ✅ / ❌

### Step 2: Pull Request 생성

```bash
# GitHub CLI 사용
gh pr create \
  --base main \
  --head feature/eks \
  --title "feat: Production environment deployment" \
  --body "$(cat <<'EOF'
## 변경 사항

### 인프라 설정
- ✅ Prod 환경 Terraform 설정 추가
- ✅ Multi-AZ 구성 (고가용성)
- ✅ Bootstrap S3 백엔드 통합 (단일 버킷)

### 주요 리소스
- **VPC**: Multi-AZ (2개 AZ)
- **EKS**: 1.35, 노드 6개 (t3.medium/large)
- **RDS**: PostgreSQL 18.1, Multi-AZ, db.t4g.small
- **ElastiCache**: Valkey, Primary + Replica
- **ALB**: Public + Management

### CI/CD
- ✅ GitHub Actions 워크플로우 설정
- ✅ Terraform Plan/Apply 자동화
- ✅ Discord 알림 통합

### 문서
- ✅ 배포 가이드
- ✅ 검증 스크립트 (33개 속성)
- ✅ 트러블슈팅 가이드

## 배포 계획

### 예상 소요 시간
- Terraform Plan: 2-3분
- Terraform Apply: 20-30분

### 예상 비용
- **월간 비용**: ~$498
- **주요 항목**: EKS ($253), NAT Gateway ($64), RDS ($60)

## 체크리스트

### 배포 전
- [x] Terraform validate 통과
- [x] 검증 스크립트 작성
- [x] 문서 작성
- [ ] GitHub Secrets 설정 확인
- [ ] Terraform Plan 검토
- [ ] 팀 리뷰 완료

### 배포 후
- [ ] EKS 클러스터 접근 확인
- [ ] RDS 연결 확인
- [ ] ALB 상태 확인
- [ ] 도메인 DNS 확인
- [ ] CloudWatch 모니터링 확인

## 롤백 계획

문제 발생 시:
1. GitHub에서 revert 커밋 생성
2. 또는 `terraform destroy` 실행

## 참고 문서

- [Prod 배포 가이드](PROD_DEPLOYMENT_GUIDE.md)
- [배포 체크리스트](PROD_DEPLOYMENT_CHECKLIST.md)
- [GitHub Actions 가이드](docs/GITHUB_ACTIONS_GUIDE.md)
EOF
)"
```

**또는 GitHub 웹 UI 사용**:
1. https://github.com/YOUR_ORG/popcorn-terraform-feature/compare/main...feature/eks
2. PR 제목 및 설명 작성
3. **Create pull request** 클릭

**완료 확인**: ✅ / ❌

### Step 3: Terraform Plan 검토

PR 생성 후 자동으로 실행되는 Plan 결과를 검토합니다.

**확인 사항**:
- [ ] Plan이 성공적으로 완료되었는가?
- [ ] 생성될 리소스 수가 예상과 일치하는가?
- [ ] 변경되거나 삭제될 리소스가 없는가?
- [ ] Security Group 규칙이 적절한가?
- [ ] Multi-AZ 설정이 올바른가?

**예상 Plan 결과**:
```
Plan: ~80 to add, 0 to change, 0 to destroy.

주요 리소스:
- VPC 및 서브넷 (6개)
- NAT Gateway (2개)
- EKS 클러스터 및 노드 그룹
- RDS (Multi-AZ)
- ElastiCache (2 nodes)
- ALB (2개)
- Security Groups (10개)
- IAM Roles (5개)
- Route53 레코드 (5개)
- CloudWatch 대시보드 및 알람
```

**완료 확인**: ✅ / ❌

### Step 4: 팀 리뷰

- [ ] DevOps 팀원 리뷰 요청
- [ ] Plan 결과 공유 및 검토
- [ ] 보안 검토 완료
- [ ] 비용 검토 완료
- [ ] 승인 완료

**완료 확인**: ✅ / ❌

### Step 5: PR 머지

```bash
# GitHub CLI 사용
gh pr merge --squash

# 또는 웹 UI에서 "Squash and merge" 클릭
```

**완료 확인**: ✅ / ❌

### Step 6: Terraform Apply 승인

PR 머지 후 GitHub Actions에서:

1. **Actions** 탭으로 이동
2. `terraform-apply` 워크플로우 확인
3. **Environment: prod** 승인 대기 확인
4. **Review deployments** 클릭
5. 최종 검토 후 **Approve and deploy** 클릭

**완료 확인**: ✅ / ❌

### Step 7: 배포 모니터링

Apply 진행 중 모니터링:

- [ ] GitHub Actions 로그 실시간 확인
- [ ] Discord 알림 확인 (설정한 경우)
- [ ] 예상 소요 시간: 20-30분

**주요 단계**:
1. ⏱️ VPC 생성 (2-3분)
2. ⏱️ EKS 클러스터 생성 (10-15분)
3. ⏱️ RDS 생성 (5-10분)
4. ⏱️ ElastiCache 생성 (3-5분)
5. ⏱️ ALB 및 기타 리소스 (2-3분)

**완료 확인**: ✅ / ❌

## 배포 후 검증

### 1. Terraform Outputs 확인

```bash
# GitHub Actions 로그에서 확인
# 또는 로컬에서:
cd envs/prod
terraform output
```

**확인 항목**:
- [ ] `vpc_id`
- [ ] `eks_cluster_endpoint`
- [ ] `rds_endpoint`
- [ ] `elasticache_primary_endpoint`
- [ ] `public_alb_dns_name`
- [ ] `management_alb_dns_name`

**완료 확인**: ✅ / ❌

### 2. EKS 클러스터 확인

```bash
# kubeconfig 설정
aws eks update-kubeconfig \
  --name goorm-popcorn-prod \
  --region ap-northeast-2

# 노드 확인
kubectl get nodes

# 예상 결과: 6개 노드 (Ready 상태)
```

**확인 항목**:
- [ ] 노드 6개 모두 Ready 상태
- [ ] 노드가 2개 AZ에 분산되어 있음
- [ ] EBS CSI Driver 설치 확인

**완료 확인**: ✅ / ❌

### 3. RDS 확인

```bash
# RDS 상태 확인
aws rds describe-db-instances \
  --db-instance-identifier goorm-popcorn-prod \
  --region ap-northeast-2 \
  --query 'DBInstances[0].[DBInstanceStatus,MultiAZ,Engine,EngineVersion]'

# 예상 결과: ["available", true, "postgres", "18.1"]
```

**확인 항목**:
- [ ] 상태: `available`
- [ ] Multi-AZ: `true`
- [ ] 엔진: PostgreSQL 18.1
- [ ] 백업 보존 기간: 7일

**완료 확인**: ✅ / ❌

### 4. ElastiCache 확인

```bash
# ElastiCache 상태 확인
aws elasticache describe-replication-groups \
  --replication-group-id goorm-popcorn-cache-prod \
  --region ap-northeast-2 \
  --query 'ReplicationGroups[0].[Status,AutomaticFailover,MultiAZ]'

# 예상 결과: ["available", "enabled", "enabled"]
```

**확인 항목**:
- [ ] 상태: `available`
- [ ] Automatic Failover: `enabled`
- [ ] Multi-AZ: `enabled`
- [ ] 노드 수: 2개

**완료 확인**: ✅ / ❌

### 5. ALB 확인

```bash
# ALB 상태 확인
aws elbv2 describe-load-balancers \
  --region ap-northeast-2 \
  --query 'LoadBalancers[?contains(LoadBalancerName, `goorm-popcorn-prod`)].{Name:LoadBalancerName,State:State.Code,DNS:DNSName}'
```

**확인 항목**:
- [ ] Public ALB 상태: `active`
- [ ] Management ALB 상태: `active`
- [ ] DNS 이름 확인

**완료 확인**: ✅ / ❌

### 6. 도메인 확인

```bash
# DNS 레코드 확인
nslookup goormpopcorn.shop
nslookup api.goormpopcorn.shop
nslookup kafka.goormpopcorn.shop
nslookup argocd.goormpopcorn.shop
nslookup grafana.goormpopcorn.shop
```

**확인 항목**:
- [ ] 모든 도메인이 ALB를 가리킴
- [ ] DNS 전파 완료 (최대 48시간 소요 가능)

**완료 확인**: ✅ / ❌

### 7. CloudWatch 모니터링 확인

```bash
# CloudWatch 대시보드 URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#dashboards:"

# 알람 확인
aws cloudwatch describe-alarms \
  --alarm-name-prefix goorm-popcorn-prod \
  --region ap-northeast-2
```

**확인 항목**:
- [ ] 대시보드 생성 확인
- [ ] 알람 설정 확인
- [ ] SNS 토픽 생성 확인

**완료 확인**: ✅ / ❌

### 8. Security Groups 확인

```bash
# Security Groups 확인
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=goorm-popcorn" \
  --region ap-northeast-2 \
  --query 'SecurityGroups[].{Name:GroupName,ID:GroupId}'
```

**확인 항목**:
- [ ] Public ALB SG: 0.0.0.0/0 허용
- [ ] Management ALB SG: 화이트리스트 IP만 허용
- [ ] EKS Node SG: ALB에서만 허용
- [ ] RDS SG: EKS Node에서만 허용
- [ ] ElastiCache SG: EKS Node에서만 허용

**완료 확인**: ✅ / ❌

## 배포 후 작업

### 1. 애플리케이션 배포 준비

- [ ] EKS 클러스터에 AWS Load Balancer Controller 설치
- [ ] Cluster Autoscaler 또는 Karpenter 설치
- [ ] Metrics Server 설치
- [ ] ArgoCD 설치 및 설정

### 2. 데이터베이스 초기화

- [ ] RDS 마스터 비밀번호 Secrets Manager에서 확인
- [ ] 데이터베이스 연결 테스트
- [ ] 스키마 생성 (애플리케이션 배포 시 자동)

### 3. 모니터링 설정

- [ ] Grafana 대시보드 설정
- [ ] Prometheus 메트릭 수집 설정
- [ ] 알람 테스트
- [ ] 로그 수집 설정 (CloudWatch Logs)

### 4. 보안 강화

- [ ] Security Group 규칙 재검토
- [ ] IAM 정책 최소화
- [ ] Secrets Manager 확인
- [ ] 암호화 설정 확인
- [ ] 정기 보안 감사 계획 수립

### 5. 백업 및 재해 복구

- [ ] RDS 자동 백업 확인 (7일)
- [ ] RDS 스냅샷 생성 테스트
- [ ] 재해 복구 절차 문서화
- [ ] 정기 백업 테스트 계획 수립

### 6. 비용 모니터링

- [ ] AWS Cost Explorer 설정
- [ ] 비용 알람 설정
- [ ] 월간 비용 리포트 자동화
- [ ] 비용 최적화 검토 (Reserved Instance, Savings Plans)

## 문제 발생 시 대응

### 즉시 롤백이 필요한 경우

```bash
# 방법 1: GitHub에서 revert
git revert HEAD
git push origin main

# 방법 2: Terraform destroy (주의!)
cd envs/prod
terraform destroy
```

### 특정 리소스만 문제가 있는 경우

```bash
# 문제 리소스만 제거
cd envs/prod
terraform destroy -target=module.RESOURCE_NAME

# 재생성
terraform apply -target=module.RESOURCE_NAME
```

### 긴급 연락망

- **DevOps Lead**: [연락처]
- **인프라 담당**: [연락처]
- **AWS Support**: [케이스 번호]
- **Slack**: #devops-emergency

## 최종 확인

배포 완료 후 모든 항목을 확인했습니까?

- [ ] ✅ 모든 리소스가 정상적으로 생성됨
- [ ] ✅ EKS 클러스터 접근 가능
- [ ] ✅ RDS 연결 가능
- [ ] ✅ ElastiCache 연결 가능
- [ ] ✅ ALB 정상 동작
- [ ] ✅ 도메인 DNS 설정 완료
- [ ] ✅ CloudWatch 모니터링 활성화
- [ ] ✅ 보안 설정 확인 완료
- [ ] ✅ 팀에 배포 완료 공지

---

**배포 일시**: _______________
**배포 담당자**: _______________
**검토자**: _______________
**승인자**: _______________

**배포 결과**: ✅ 성공 / ❌ 실패 / ⚠️ 부분 성공

**비고**:
_______________________________________________
_______________________________________________
_______________________________________________
