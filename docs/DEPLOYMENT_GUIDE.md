# Terraform 인프라 배포 가이드

## 개요

이 문서는 Goorm Popcorn 프로젝트의 Terraform 인프라를 Dev 및 Prod 환경에 배포하는 절차를 설명합니다.

## 사전 요구사항

### 필수 도구

- **Terraform**: v1.5.0 이상
- **AWS CLI**: v2.0 이상
- **jq**: JSON 파싱 도구
- **Git**: 버전 관리

### AWS 자격증명

```bash
# AWS CLI 설정
aws configure

# 또는 환경 변수 설정
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-2"
```

### S3 백엔드 및 DynamoDB 테이블

Bootstrap 단계에서 이미 생성되어 있어야 합니다:

- **Dev 환경**:
  - S3 버킷: `goorm-popcorn-tfstate`
  - DynamoDB 테이블: `goorm-popcorn-tfstate-lock`
  - State 키: `dev/terraform.tfstate`

- **Prod 환경**:
  - S3 버킷: `popcorn-terraform-state`
  - DynamoDB 테이블: `popcorn-terraform-state-lock`
  - State 키: `prod/terraform.tfstate`

## Dev 환경 배포

### 1. 환경 변수 설정

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 편집하여 환경에 맞게 수정:

```hcl
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
# ... (나머지 설정)

# 화이트리스트 IP (관리 도구 접근)
management_whitelist_ips = [
  "YOUR_OFFICE_IP/32",
  "YOUR_VPN_IP/32"
]
```

### 2. Terraform 초기화

```bash
terraform init
```

### 3. Terraform Plan 실행

```bash
terraform plan -out=dev.tfplan
```

Plan 출력을 검토하여 생성될 리소스를 확인합니다.

### 4. 속성 검증

```bash
cd ../..
ENV=dev ./scripts/validate-properties.sh
```

모든 속성 검증이 통과하는지 확인합니다.

### 5. Terraform Apply 실행

```bash
cd envs/dev
terraform apply dev.tfplan
```

### 6. 배포 확인

```bash
# VPC 확인
terraform output vpc_id

# EKS 클러스터 확인
terraform output eks_cluster_name
aws eks describe-cluster --name $(terraform output -raw eks_cluster_name)

# RDS 확인
terraform output rds_endpoint

# ALB 확인
terraform output public_alb_dns_name
terraform output management_alb_dns_name
```

### 7. EKS kubeconfig 설정

```bash
aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region ap-northeast-2
kubectl get nodes
```

## Prod 환경 배포

### 1. 환경 변수 설정

```bash
cd envs/prod
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 편집하여 Prod 환경에 맞게 수정:

```hcl
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
# ... (나머지 설정)

# RDS 설정 (Multi-AZ, 7일 백업)
rds_multi_az = true
rds_backup_retention_period = 7
rds_performance_insights_enabled = true

# ElastiCache 설정 (Primary + Replica)
elasticache_num_cache_nodes = 2
elasticache_automatic_failover_enabled = true
```

### 2-7. Dev 환경과 동일한 절차 수행

```bash
terraform init
terraform plan -out=prod.tfplan

# 속성 검증
cd ../..
ENV=prod ./scripts/validate-properties.sh

# Apply
cd envs/prod
terraform apply prod.tfplan

# 배포 확인
terraform output
```

## 롤백 절차

### 특정 리소스 롤백

```bash
# 특정 리소스 제거
terraform destroy -target=module.eks

# 특정 리소스 재생성
terraform apply -target=module.eks
```

### 전체 롤백

```bash
# 모든 리소스 제거
terraform destroy

# 확인 프롬프트에서 'yes' 입력
```

### Git 기반 롤백

```bash
# 이전 커밋으로 되돌리기
git revert HEAD

# 변경 사항 적용
terraform plan
terraform apply
```

## 트러블슈팅

### 1. State 잠금 오류

```bash
# 오류 메시지
Error: Error acquiring the state lock

# 해결 방법
terraform force-unlock LOCK_ID
```

### 2. 리소스 생성 실패

```bash
# 오류 로그 확인
terraform show

# 특정 리소스 재생성
terraform taint module.eks.aws_eks_cluster.main
terraform apply
```

### 3. VPC Endpoint 생성 실패

```bash
# VPC Endpoint 서비스 가용성 확인
aws ec2 describe-vpc-endpoint-services --region ap-northeast-2

# 재시도
terraform apply
```

### 4. EKS 클러스터 접근 불가

```bash
# kubeconfig 업데이트
aws eks update-kubeconfig --name CLUSTER_NAME --region ap-northeast-2

# IAM 권한 확인
aws sts get-caller-identity

# EKS 클러스터 상태 확인
aws eks describe-cluster --name CLUSTER_NAME
```

### 5. RDS 연결 실패

```bash
# Security Group 규칙 확인
aws ec2 describe-security-groups --group-ids SG_ID

# RDS 엔드포인트 확인
terraform output rds_endpoint

# 연결 테스트
psql -h RDS_ENDPOINT -U postgres -d popcorn
```

## 모니터링

### CloudWatch 대시보드

```bash
# CloudWatch 대시보드 URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-2#dashboards:"
```

### 알람 확인

```bash
# CloudWatch 알람 목록
aws cloudwatch describe-alarms --region ap-northeast-2
```

### 로그 확인

```bash
# EKS 클러스터 로그
aws logs tail /aws/eks/CLUSTER_NAME/cluster --follow

# RDS 로그
aws rds describe-db-log-files --db-instance-identifier DB_INSTANCE_ID
```

## 비용 관리

### 비용 추정

```bash
# Terraform plan으로 생성될 리소스 확인
terraform plan

# AWS Cost Explorer에서 예상 비용 확인
```

### 비용 최적화

- **Dev 환경**: 단일 NAT Gateway, 작은 인스턴스 타입
- **Prod 환경**: Karpenter Spot Instance 활성화
- **리소스 태그**: 모든 리소스에 Environment, Project 태그 적용

### 불필요한 리소스 정리

```bash
# Dev 환경 전체 제거 (업무 시간 외)
cd envs/dev
terraform destroy

# Prod 환경은 항상 유지
```

## 보안 체크리스트

- [ ] AWS 자격증명이 안전하게 관리되고 있는가?
- [ ] S3 백엔드 버킷이 암호화되어 있는가?
- [ ] DynamoDB 테이블이 암호화되어 있는가?
- [ ] RDS가 암호화되어 있는가?
- [ ] ElastiCache가 전송 중 암호화를 사용하는가?
- [ ] Management ALB가 IP 화이트리스트로 보호되고 있는가?
- [ ] 모든 보안 그룹이 최소 권한 원칙을 따르는가?
- [ ] IAM 역할이 최소 권한 원칙을 따르는가?
- [ ] Secrets Manager에 민감 정보가 저장되어 있는가?

## 참고 자료

- [Terraform 공식 문서](https://www.terraform.io/docs)
- [AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS 모범 사례](https://aws.github.io/aws-eks-best-practices/)
- [Terraform 모범 사례](https://www.terraform-best-practices.com/)

## 지원

문제가 발생하면 DevOps 팀에 문의하세요:
- Slack: #devops-support
- Email: devops@goorm.io

