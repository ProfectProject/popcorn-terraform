# 배포 전 체크리스트

## 개요

이 문서는 Terraform 인프라를 실제 AWS 환경에 배포하기 전에 확인해야 할 사항들을 정리한 체크리스트입니다.

## 1. AWS 계정 및 자격증명

### AWS 계정 확인
- [ ] AWS 계정이 생성되어 있는가?
- [ ] 계정에 충분한 권한이 있는가? (AdministratorAccess 또는 필요한 서비스별 권한)
- [ ] 계정의 서비스 제한(Service Quotas)을 확인했는가?

### IAM 사용자 생성
```bash
# AWS 콘솔에서 IAM 사용자 생성
# 1. IAM > Users > Add user
# 2. User name: terraform-deploy
# 3. Access type: Programmatic access
# 4. Permissions: AdministratorAccess (또는 필요한 권한만)
# 5. 액세스 키 ID와 시크릿 액세스 키 저장
```

### AWS CLI 설정
```bash
# AWS CLI 설치 확인
aws --version

# AWS CLI 설정
aws configure
# AWS Access Key ID: [YOUR_ACCESS_KEY]
# AWS Secret Access Key: [YOUR_SECRET_KEY]
# Default region name: ap-northeast-2
# Default output format: json

# 설정 확인
aws sts get-caller-identity
```

## 2. S3 백엔드 및 DynamoDB 테이블

### Bootstrap 리소스 생성

**Dev 환경**:
```bash
cd bootstrap
terraform init
terraform plan -var="environment=dev" -var="bucket_name=goorm-popcorn-tfstate"
terraform apply -var="environment=dev" -var="bucket_name=goorm-popcorn-tfstate"
```

**Prod 환경**:
```bash
terraform plan -var="environment=prod" -var="bucket_name=popcorn-terraform-state"
terraform apply -var="environment=prod" -var="bucket_name=popcorn-terraform-state"
```

### 생성 확인
```bash
# S3 버킷 확인
aws s3 ls | grep tfstate

# DynamoDB 테이블 확인
aws dynamodb list-tables | grep tfstate-lock
```

## 3. Route53 호스팅 존

### 호스팅 존 확인
```bash
# 호스팅 존 목록 확인
aws route53 list-hosted-zones

# goormpopcorn.shop 호스팅 존이 없으면 생성
aws route53 create-hosted-zone \
  --name goormpopcorn.shop \
  --caller-reference $(date +%s)
```

### 네임서버 설정
```bash
# 호스팅 존의 네임서버 확인
aws route53 get-hosted-zone --id HOSTED_ZONE_ID

# 도메인 등록 업체에서 네임서버 설정
# (예: ns-1234.awsdns-12.org, ns-5678.awsdns-34.com 등)
```

## 4. ACM 인증서

### 인증서 요청
```bash
# ACM 인증서 요청 (ap-northeast-2 리전)
aws acm request-certificate \
  --domain-name goormpopcorn.shop \
  --subject-alternative-names "*.goormpopcorn.shop" \
  --validation-method DNS \
  --region ap-northeast-2

# 인증서 ARN 저장
export CERTIFICATE_ARN="arn:aws:acm:ap-northeast-2:ACCOUNT_ID:certificate/CERT_ID"
```

### DNS 검증
```bash
# 인증서 상세 정보 확인
aws acm describe-certificate \
  --certificate-arn $CERTIFICATE_ARN \
  --region ap-northeast-2

# Route53에 CNAME 레코드 추가 (자동 또는 수동)
# 인증서 상태가 ISSUED가 될 때까지 대기 (최대 30분)
```

## 5. ECR 리포지토리

### ECR 리포지토리 생성
```bash
cd global/ecr
terraform init
terraform plan
terraform apply

# 생성된 리포지토리 확인
aws ecr describe-repositories --region ap-northeast-2
```

## 6. 환경 변수 파일 설정

### Dev 환경 설정
```bash
cd envs/dev

# terraform.tfvars 파일 생성
cat > terraform.tfvars <<EOF
# 환경 설정
environment = "dev"
region      = "ap-northeast-2"

# VPC 설정
vpc_cidr = "10.0.0.0/16"
public_subnets = [
  {
    name = "popcorn-dev-public-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.1.0/24"
  }
]
private_subnets = [
  {
    name = "popcorn-dev-private-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.11.0/24"
  }
]
data_subnets = [
  {
    name = "popcorn-dev-data-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.21.0/24"
  }
]
single_nat_gateway = true

# EKS 설정
eks_cluster_version = "1.35"
eks_node_instance_types = ["t3.medium"]
eks_node_desired_size = 2
eks_node_min_size = 2
eks_node_max_size = 5

# RDS 설정
rds_instance_class = "db.t4g.micro"
rds_multi_az = false
rds_backup_retention_period = 1
rds_performance_insights_enabled = false
rds_master_password = "CHANGE_ME_STRONG_PASSWORD"

# ElastiCache 설정
elasticache_node_type = "cache.t4g.micro"
elasticache_num_cache_nodes = 1
elasticache_automatic_failover_enabled = false

# ACM 인증서 ARN
certificate_arn = "$CERTIFICATE_ARN"

# Route53 호스팅 존 ID
route53_zone_id = "HOSTED_ZONE_ID"

# 화이트리스트 IP (관리 도구 접근)
management_whitelist_ips = [
  "YOUR_OFFICE_IP/32",
  "YOUR_VPN_IP/32"
]

# 태그
tags = {
  Environment = "dev"
  Project     = "popcorn"
  ManagedBy   = "terraform"
}
EOF
```

### Prod 환경 설정
```bash
cd envs/prod

# terraform.tfvars 파일 생성 (Multi-AZ 설정)
cat > terraform.tfvars <<EOF
# 환경 설정
environment = "prod"
region      = "ap-northeast-2"

# VPC 설정 (Multi-AZ)
vpc_cidr = "10.0.0.0/16"
public_subnets = [
  {
    name = "popcorn-prod-public-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.1.0/24"
  },
  {
    name = "popcorn-prod-public-2c"
    az   = "ap-northeast-2c"
    cidr = "10.0.2.0/24"
  }
]
private_subnets = [
  {
    name = "popcorn-prod-private-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.11.0/24"
  },
  {
    name = "popcorn-prod-private-2c"
    az   = "ap-northeast-2c"
    cidr = "10.0.12.0/24"
  }
]
data_subnets = [
  {
    name = "popcorn-prod-data-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.21.0/24"
  },
  {
    name = "popcorn-prod-data-2c"
    az   = "ap-northeast-2c"
    cidr = "10.0.22.0/24"
  }
]
single_nat_gateway = false

# EKS 설정
eks_cluster_version = "1.35"
eks_node_instance_types = ["t3.medium", "t3.large"]
eks_node_desired_size = 3
eks_node_min_size = 3
eks_node_max_size = 5

# RDS 설정 (Multi-AZ)
rds_instance_class = "db.t4g.micro"
rds_multi_az = true
rds_backup_retention_period = 7
rds_performance_insights_enabled = true
rds_master_password = "CHANGE_ME_STRONG_PASSWORD"

# ElastiCache 설정 (Primary + Replica)
elasticache_node_type = "cache.t4g.small"
elasticache_num_cache_nodes = 2
elasticache_automatic_failover_enabled = true

# ACM 인증서 ARN
certificate_arn = "$CERTIFICATE_ARN"

# Route53 호스팅 존 ID
route53_zone_id = "HOSTED_ZONE_ID"

# 화이트리스트 IP (관리 도구 접근)
management_whitelist_ips = [
  "YOUR_OFFICE_IP/32",
  "YOUR_VPN_IP/32"
]

# 태그
tags = {
  Environment = "prod"
  Project     = "popcorn"
  ManagedBy   = "terraform"
}
EOF
```

## 7. GitHub Secrets 설정

### GitHub 저장소 설정
```bash
# GitHub CLI 설치 확인
gh --version

# GitHub 로그인
gh auth login

# Secrets 설정
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_KEY"
gh secret set SLACK_WEBHOOK_URL --body "YOUR_SLACK_WEBHOOK_URL"  # 선택적
```

### 수동 설정 (GitHub 웹 UI)
1. GitHub 저장소 페이지로 이동
2. **Settings** > **Secrets and variables** > **Actions**
3. **New repository secret** 클릭
4. 다음 Secrets 추가:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `SLACK_WEBHOOK_URL` (선택적)

## 8. 서비스 제한 확인

### AWS Service Quotas 확인
```bash
# VPC 제한 확인
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --region ap-northeast-2

# EKS 제한 확인
aws service-quotas get-service-quota \
  --service-code eks \
  --quota-code L-1194D53C \
  --region ap-northeast-2

# RDS 제한 확인
aws service-quotas get-service-quota \
  --service-code rds \
  --quota-code L-7B6409FD \
  --region ap-northeast-2
```

### 필요시 제한 증가 요청
```bash
# Service Quotas 증가 요청
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10 \
  --region ap-northeast-2
```

## 9. 비용 예측

### AWS Pricing Calculator 사용
1. [AWS Pricing Calculator](https://calculator.aws/) 접속
2. 다음 리소스 추가:
   - VPC (NAT Gateway)
   - EKS (Control Plane + Nodes)
   - RDS PostgreSQL
   - ElastiCache Valkey
   - ALB
   - Route53
   - CloudWatch

### 예상 월간 비용 (Dev 환경)
- VPC (NAT Gateway): ~$32
- EKS Control Plane: ~$73
- EKS Nodes (t3.medium x 2): ~$60
- RDS (db.t4g.micro): ~$15
- ElastiCache (cache.t4g.micro): ~$12
- ALB x 2: ~$32
- Route53: ~$1
- CloudWatch: ~$10
- **총 예상 비용: ~$235/월**

### 예상 월간 비용 (Prod 환경)
- VPC (NAT Gateway x 2): ~$64
- EKS Control Plane: ~$73
- EKS Nodes (t3.medium x 3): ~$90
- RDS (db.t4g.micro, Multi-AZ): ~$30
- ElastiCache (cache.t4g.small x 2): ~$48
- ALB x 2: ~$32
- Route53: ~$1
- CloudWatch: ~$20
- **총 예상 비용: ~$358/월**

## 10. 보안 체크리스트

- [ ] AWS 자격증명이 안전하게 저장되어 있는가?
- [ ] RDS 마스터 비밀번호가 강력한가? (최소 16자, 대소문자/숫자/특수문자 포함)
- [ ] Management ALB 화이트리스트 IP가 올바른가?
- [ ] GitHub Secrets가 안전하게 설정되어 있는가?
- [ ] S3 버킷 암호화가 활성화되어 있는가?
- [ ] DynamoDB 테이블 암호화가 활성화되어 있는가?

## 11. 배포 순서

### 1단계: Bootstrap (S3 백엔드)
```bash
cd bootstrap
terraform init
terraform apply
```

### 2단계: Global 리소스 (ECR, Route53)
```bash
cd global/ecr
terraform init
terraform apply

cd ../route53-acm
terraform init
terraform apply
```

### 3단계: Dev 환경
```bash
cd envs/dev
terraform init
terraform plan -out=dev.tfplan
terraform apply dev.tfplan
```

### 4단계: Prod 환경
```bash
cd envs/prod
terraform init
terraform plan -out=prod.tfplan
terraform apply prod.tfplan
```

## 12. 배포 후 확인

### 리소스 확인
```bash
# VPC 확인
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=popcorn"

# EKS 클러스터 확인
aws eks list-clusters --region ap-northeast-2
aws eks describe-cluster --name CLUSTER_NAME

# RDS 확인
aws rds describe-db-instances --region ap-northeast-2

# ElastiCache 확인
aws elasticache describe-replication-groups --region ap-northeast-2

# ALB 확인
aws elbv2 describe-load-balancers --region ap-northeast-2
```

### EKS 접근 확인
```bash
# kubeconfig 설정
aws eks update-kubeconfig --name CLUSTER_NAME --region ap-northeast-2

# 노드 확인
kubectl get nodes

# 네임스페이스 확인
kubectl get namespaces
```

### 도메인 확인
```bash
# DNS 레코드 확인
nslookup goormpopcorn.shop
nslookup kafka.goormpopcorn.shop
nslookup argocd.goormpopcorn.shop
nslookup grafana.goormpopcorn.shop
```

## 13. 롤백 계획

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

## 14. 모니터링 설정

### CloudWatch 대시보드 확인
```bash
# CloudWatch 대시보드 URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#dashboards:"
```

### 알람 확인
```bash
# CloudWatch 알람 목록
aws cloudwatch describe-alarms --region ap-northeast-2
```

## 15. 최종 체크리스트

배포 전 모든 항목을 확인하세요:

- [ ] AWS 계정 및 자격증명 설정 완료
- [ ] S3 백엔드 및 DynamoDB 테이블 생성 완료
- [ ] Route53 호스팅 존 생성 및 네임서버 설정 완료
- [ ] ACM 인증서 발급 및 검증 완료
- [ ] ECR 리포지토리 생성 완료
- [ ] terraform.tfvars 파일 설정 완료
- [ ] GitHub Secrets 설정 완료
- [ ] 서비스 제한 확인 완료
- [ ] 비용 예측 완료
- [ ] 보안 체크리스트 확인 완료
- [ ] 배포 순서 이해 완료
- [ ] 롤백 계획 수립 완료

## 지원

문제가 발생하면 DevOps 팀에 문의하세요:
- Slack: #devops-support
- Email: devops@goorm.io

