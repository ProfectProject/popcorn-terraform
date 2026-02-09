# 배포 준비 완료 ✅

## 현재 상태

Terraform 인프라 리팩토링 프로젝트가 배포 준비 완료 상태입니다!

### ✅ 준비 완료된 항목

1. **AWS 리소스**
   - ✅ S3 백엔드: `goorm-popcorn-tfstate` (단일 버킷)
   - ✅ DynamoDB 테이블: `goorm-popcorn-tfstate-lock`
   - ✅ Route53 호스팅 존: `goormpopcorn.shop`
   - ✅ ACM 인증서: 발급 완료 (ISSUED)
   - ✅ ECR 리포지토리: 8개 서비스 리포지토리 생성 완료

2. **Terraform 코드**
   - ✅ 모든 모듈 작성 완료
   - ✅ Dev/Prod 환경 설정 완료
   - ✅ Terraform validate 통과
   - ✅ Terraform fmt 통과

3. **검증 스크립트**
   - ✅ 33개 속성 검증 스크립트 작성
   - ✅ 스크립트 구조 테스트 통과

4. **문서화**
   - ✅ 배포 가이드
   - ✅ GitHub Actions 가이드
   - ✅ 배포 전 체크리스트
   - ✅ 모듈 README

### ⚠️ 추가 작업 필요

1. **환경 변수 설정**
   - ⚠️ `envs/dev/terraform.tfvars` - RDS 비밀번호 및 화이트리스트 IP 설정 필요
   - ⚠️ `envs/prod/terraform.tfvars` - 생성 및 설정 필요

## 빠른 시작 가이드

### 1. AWS 리소스 확인

```bash
cd popcorn-terraform-feature
./scripts/check-aws-resources.sh
```

### 2. Dev 환경 배포 준비

```bash
# 배포 준비 스크립트 실행
ENV=dev ./scripts/prepare-deployment.sh
```

이 스크립트는 다음을 수행합니다:
- AWS 자격증명 확인
- S3 백엔드 및 DynamoDB 테이블 확인/생성
- terraform.tfvars 파일 검증
- Terraform 초기화 및 검증
- Terraform Plan 실행

### 3. terraform.tfvars 설정

```bash
cd envs/dev
vi terraform.tfvars
```

**필수 수정 항목**:
```hcl
# RDS 마스터 비밀번호 (강력한 비밀번호로 변경)
rds_master_password = "CHANGE_ME_STRONG_PASSWORD"

# 화이트리스트 IP (실제 IP로 변경)
management_whitelist_ips = [
  "YOUR_OFFICE_IP/32",
  "YOUR_VPN_IP/32"
]

# ACM 인증서 ARN (자동 입력됨)
certificate_arn = "arn:aws:acm:ap-northeast-2:375896310755:certificate/085e3315-785c-480d-93c2-57f656b60f7b"

# Route53 호스팅 존 ID (자동 입력됨)
route53_zone_id = "Z00058041V7BR3D5EUN1R"
```

### 4. Dev 환경 배포

```bash
cd envs/dev

# Plan 검토
terraform plan -out=dev.tfplan

# 속성 검증 (선택적)
cd ../..
ENV=dev ./scripts/validate-properties.sh

# Apply 실행
cd envs/dev
terraform apply dev.tfplan
```

### 5. 배포 확인

```bash
# 출력 값 확인
terraform output

# EKS 클러스터 접근
aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region ap-northeast-2
kubectl get nodes

# 도메인 확인
nslookup dev.goormpopcorn.shop
```

## Prod 환경 배포

### 1. Prod 환경 설정

Prod 환경은 Dev와 동일한 S3 버킷을 사용하며, 키(경로)로 구분됩니다:

```
goorm-popcorn-tfstate/
├── dev/terraform.tfstate
└── prod/terraform.tfstate
```

백엔드는 이미 생성되어 있으므로 바로 배포 가능합니다.

### 2. Prod 환경 배포

```bash
# 배포 준비
ENV=prod ./scripts/prepare-deployment.sh

# terraform.tfvars 설정
cd envs/prod
cp ../dev/terraform.tfvars terraform.tfvars
vi terraform.tfvars  # Prod 설정으로 수정

# 배포
terraform init
terraform plan -out=prod.tfplan
terraform apply prod.tfplan
```

## 예상 비용

### Dev 환경
- VPC (NAT Gateway): ~$32/월
- EKS (Control Plane + Nodes): ~$133/월
- RDS (db.t4g.micro): ~$15/월
- ElastiCache (cache.t4g.micro): ~$12/월
- ALB x 2: ~$32/월
- 기타: ~$11/월
- **총 예상: ~$235/월**

### Prod 환경
- VPC (NAT Gateway x 2): ~$64/월
- EKS (Control Plane + Nodes): ~$163/월
- RDS (db.t4g.micro, Multi-AZ): ~$30/월
- ElastiCache (cache.t4g.small x 2): ~$48/월
- ALB x 2: ~$32/월
- 기타: ~$21/월
- **총 예상: ~$358/월**

## 롤백 계획

### 배포 실패 시

```bash
# 특정 리소스 제거
terraform destroy -target=module.eks

# 전체 롤백
terraform destroy
```

### State 백업

```bash
# 배포 전 State 백업
aws s3 cp s3://goorm-popcorn-tfstate/dev/terraform.tfstate \
  ./backup/terraform.tfstate.$(date +%Y%m%d_%H%M%S)
```

## 모니터링

### CloudWatch 대시보드

배포 후 다음 URL에서 모니터링:
- https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#dashboards:

### 알람 확인

```bash
# CloudWatch 알람 목록
aws cloudwatch describe-alarms --region ap-northeast-2
```

## 트러블슈팅

### 일반적인 문제

1. **State 잠금 오류**
   ```bash
   terraform force-unlock LOCK_ID
   ```

2. **리소스 생성 실패**
   - AWS 콘솔에서 리소스 상태 확인
   - CloudWatch Logs에서 에러 로그 확인
   - 필요시 수동으로 리소스 정리 후 재시도

3. **Plan 실행 시간 초과**
   - 네트워크 연결 확인
   - AWS 자격증명 유효성 확인
   - 리전 설정 확인

## 다음 단계

배포 완료 후:

1. **애플리케이션 배포**
   - ArgoCD 설정
   - Helm 차트 배포
   - 서비스 확인

2. **모니터링 설정**
   - Grafana 대시보드 구성
   - 알람 테스트
   - 로그 수집 확인

3. **보안 강화**
   - Security Group 규칙 재검토
   - IAM 정책 최소화
   - 정기 보안 감사

## 지원

문제가 발생하면:
- Slack: #devops-support
- Email: devops@goorm.io
- 문서: `docs/` 디렉터리 참조

## 참고 문서

- [배포 가이드](docs/DEPLOYMENT_GUIDE.md)
- [배포 전 체크리스트](docs/PRE_DEPLOYMENT_CHECKLIST.md)
- [GitHub Actions 가이드](docs/GITHUB_ACTIONS_GUIDE.md)
- [완료 체크리스트](docs/COMPLETION_CHECKLIST.md)

---

**작성일**: 2026-02-09  
**작성자**: DevOps Team  
**버전**: 1.0.0

