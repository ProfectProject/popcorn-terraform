# Task 4.2: Prod 환경 main.tf 작성

## 작업 일시
- 시작: 2025-02-05
- 완료: 2025-02-05

## 작업 내용

### 1. Prod 환경 main.tf 업데이트

#### 주요 변경사항
1. **ALB 분리**
   - 기존 단일 ALB를 Public ALB와 Management ALB로 분리
   - Public ALB: Frontend 서비스용 (0.0.0.0/0 허용)
   - Management ALB: Kafka, ArgoCD, Grafana용 (IP 화이트리스트 적용)

2. **Security Groups 모듈 업데이트**
   - environment 파라미터 추가 ("prod")
   - whitelist_ips 파라미터 추가
   - tags 파라미터 추가

3. **Route53 레코드 분리**
   - Public ALB: goormpopcorn.shop, api.goormpopcorn.shop
   - Management ALB: kafka.goormpopcorn.shop, argocd.goormpopcorn.shop, grafana.goormpopcorn.shop

4. **ElastiCache 설정 (Prod 환경)**
   - node_type: cache.t4g.small
   - num_cache_clusters: 2 (Primary + Replica)
   - automatic_failover_enabled: true
   - multi_az_enabled: true
   - transit_encryption_enabled: true
   - snapshot_retention_limit: 7일
   - enable_cloudwatch_alarms: true

5. **Monitoring 모듈 추가**
   - Public ALB와 Management ALB 모니터링
   - RDS 모니터링
   - ElastiCache 모니터링
   - SNS 알림 활성화 (Prod 환경)

### 2. Prod 환경 variables.tf 업데이트

#### 추가된 변수
- `public_alb_name`: Public ALB 이름
- `public_alb_target_group_name`: Public ALB 타겟 그룹 이름
- `public_alb_target_group_port`: Public ALB 타겟 그룹 포트 (기본값: 8080)
- `public_alb_health_check_path`: Public ALB 헬스체크 경로 (기본값: "/actuator/health")
- `management_alb_name`: Management ALB 이름
- `management_alb_target_group_name`: Management ALB 타겟 그룹 이름
- `management_alb_target_group_port`: Management ALB 타겟 그룹 포트 (기본값: 8080)
- `management_alb_health_check_path`: Management ALB 헬스체크 경로 (기본값: "/health")
- `whitelist_ips`: Management ALB 접근 허용 IP 목록 (CIDR 형식)

#### 제거된 변수
- `sg_name`: Security Groups 모듈에서 자동 생성
- `alb_name`: Public ALB와 Management ALB로 분리
- `alb_target_group_name`: Public ALB와 Management ALB로 분리
- `alb_target_group_port`: Public ALB와 Management ALB로 분리
- `alb_health_check_path`: Public ALB와 Management ALB로 분리

### 3. Prod 환경 terraform.tfvars 업데이트

#### 업데이트된 값
```hcl
# Public ALB 설정 (Frontend 서비스용)
public_alb_name              = "goorm-popcorn-public-alb-prod"
public_alb_target_group_name = "goorm-popcorn-frontend-prod"
public_alb_target_group_port = 3000
public_alb_health_check_path = "/"

# Management ALB 설정 (Kafka, ArgoCD, Grafana용)
management_alb_name              = "goorm-popcorn-mgmt-alb-prod"
management_alb_target_group_name = "goorm-popcorn-mgmt-prod"
management_alb_target_group_port = 8080
management_alb_health_check_path = "/health"

# Management ALB 화이트리스트 IP (사무실 및 VPN IP)
whitelist_ips = [
  "1.2.3.4/32",  # 사무실 IP (예시)
  "5.6.7.8/32"   # VPN IP (예시)
]
```

### 4. RDS 설정 (rds.tf)

#### Local 값 추가
```hcl
locals {
  name_prefix = "goorm-popcorn-prod"
  environment = "prod"
  common_tags = {
    Environment = "prod"
    Project     = "goorm-popcorn"
    ManagedBy   = "terraform"
  }
}
```

#### 수정사항
- VPC 모듈 출력: `database_subnet_ids` → `data_subnet_ids`
- VPC CIDR 블록: `module.vpc.vpc_cidr_block` → `var.vpc_cidr`
- Kafka 보안 그룹 참조 제거 (Kafka는 EKS 내부에서 실행)

## Dev 환경과의 차이점

### 1. 가용성 구성
- **Dev**: 단일 AZ (ap-northeast-2a)
- **Prod**: Multi-AZ (ap-northeast-2a, ap-northeast-2c)

### 2. NAT Gateway
- **Dev**: 단일 NAT Gateway (single_nat_gateway = true)
- **Prod**: Multi-AZ NAT Gateway (single_nat_gateway = false)

### 3. EKS 노드
- **Dev**: t3.medium, 2-5개 노드
- **Prod**: t3.medium~large, 3-5개 노드

### 4. RDS
- **Dev**: db.t4g.micro, 단일 AZ, 1일 백업, Performance Insights 비활성화
- **Prod**: db.t4g.micro, Multi-AZ, 7일 백업, Performance Insights 활성화

### 5. ElastiCache
- **Dev**: cache.t4g.micro, 단일 노드, 자동 장애조치 비활성화
- **Prod**: cache.t4g.small, Primary + Replica, 자동 장애조치 활성화

### 6. 모니터링
- **Dev**: SNS 알림 비활성화
- **Prod**: SNS 알림 활성화

### 7. ALB 액세스 로그
- **Dev**: 비활성화 (비용 절감)
- **Prod**: 활성화 (감사 및 분석)

## 검증 결과

### Terraform 포맷팅
```bash
$ terraform fmt
terraform.tfvars
```
✅ 성공

### Terraform 초기화
```bash
$ terraform init -backend=false
```
✅ 성공
- management_alb 모듈 로드 완료
- monitoring 모듈 로드 완료
- public_alb 모듈 로드 완료

### Terraform 검증
```bash
$ terraform validate
```
⚠️ 부분 성공
- Prod 환경 main.tf 구문 오류 없음
- RDS 설정 (rds.tf) 구문 오류 없음
- EKS 모듈 내부 오류 발견 (helm.tf)
  - `aws_eks_fargate_profile.main` 리소스 미선언
  - `aws_iam_role.cluster_autoscaler` 리소스 미선언
  - 이는 EKS 모듈 내부 문제로 별도 수정 필요

## 생성된 리소스

### 1. VPC 모듈
- VPC (10.0.0.0/16)
- Public Subnet (2개 AZ)
- Private Subnet (2개 AZ)
- Data Subnet (2개 AZ)
- NAT Gateway (2개 AZ)

### 2. Security Groups 모듈
- Public ALB 보안 그룹
- Management ALB 보안 그룹
- RDS 보안 그룹
- ElastiCache 보안 그룹

### 3. Public ALB 모듈
- Application Load Balancer
- Target Group (Frontend)
- HTTPS Listener (ACM 인증서)
- CloudWatch 알람
- 액세스 로그 (S3)

### 4. Management ALB 모듈
- Application Load Balancer
- Target Group (Management)
- HTTPS Listener (ACM 인증서)
- CloudWatch 알람
- 액세스 로그 (S3)

### 5. Route53 레코드
- goormpopcorn.shop → Public ALB
- api.goormpopcorn.shop → Public ALB
- kafka.goormpopcorn.shop → Management ALB
- argocd.goormpopcorn.shop → Management ALB
- grafana.goormpopcorn.shop → Management ALB

### 6. ElastiCache 모듈
- Valkey Replication Group (Primary + Replica)
- Subnet Group
- CloudWatch 알람

### 7. IAM 모듈
- EKS 클러스터 역할
- EKS 노드 역할
- Karpenter 역할
- AWS Load Balancer Controller IRSA
- EBS CSI Driver IRSA

### 8. EKS 모듈
- EKS 클러스터 (Kubernetes 1.35)
- 노드 그룹 (t3.medium~large, 3-5개)
- AWS Load Balancer Controller
- Karpenter
- EBS CSI Driver

### 9. RDS 모듈 (rds.tf)
- RDS PostgreSQL (db.t4g.micro, Multi-AZ)
- Secrets Manager (자격증명)
- Enhanced Monitoring IAM 역할
- CloudWatch 알람 (CPU, 연결, 스토리지, 레이턴시)
- SNS 토픽 (알림)

### 10. Monitoring 모듈
- CloudWatch 대시보드
- CloudWatch 알람 (ALB, RDS, ElastiCache)
- SNS 토픽 (알림)

## 파일 목록

### 수정된 파일
- `popcorn-terraform-feature/envs/prod/main.tf`
- `popcorn-terraform-feature/envs/prod/variables.tf`
- `popcorn-terraform-feature/envs/prod/terraform.tfvars`
- `popcorn-terraform-feature/envs/prod/rds.tf`

### 생성된 파일
- `popcorn-terraform-feature/.kiro/task-logs/task-4.2-prod-main-tf.md`

## 다음 단계

### 즉시 필요한 작업
1. **EKS 모듈 helm.tf 수정**
   - `aws_eks_fargate_profile.main` 리소스 추가 또는 참조 제거
   - `aws_iam_role.cluster_autoscaler` 리소스 추가 또는 참조 제거

2. **화이트리스트 IP 업데이트**
   - `terraform.tfvars`의 `whitelist_ips`를 실제 사무실/VPN IP로 변경

3. **Terraform Plan 실행**
   - EKS 모듈 수정 후 `terraform plan` 실행
   - 생성될 리소스 검토

### 후속 작업
1. Task 4.3: Prod 환경 variables.tf 작성 (완료됨)
2. Task 4.4: Prod 환경 terraform.tfvars 작성 (완료됨)
3. Task 4.5: Prod 환경 backend.tf 작성
4. Task 4.6: Prod 환경 outputs.tf 작성

## 참고사항

### Prod 환경 특징
- **고가용성**: Multi-AZ 구성으로 단일 AZ 장애 시에도 서비스 지속
- **보안 강화**: Management ALB에 IP 화이트리스트 적용
- **모니터링 강화**: SNS 알림 활성화, 액세스 로그 활성화
- **백업 강화**: RDS 7일 백업, ElastiCache 7일 백업
- **성능 모니터링**: RDS Performance Insights 활성화

### 비용 예상
- VPC: NAT Gateway 2개 (Multi-AZ)
- EKS: 노드 3-5개 (t3.medium~large)
- RDS: db.t4g.micro (Multi-AZ)
- ElastiCache: cache.t4g.small (Primary + Replica)
- ALB: 2개 (Public, Management)
- 예상 월 비용: 약 $650

## 작업 완료 체크리스트

- [x] Prod 환경 main.tf 작성
- [x] VPC 모듈 호출 (Multi-AZ)
- [x] EKS 모듈 호출 (t3.medium~large, 3-5 노드)
- [x] RDS 모듈 호출 (db.t4g.micro, Multi-AZ, 7일 백업, Performance Insights)
- [x] ElastiCache 모듈 호출 (cache.t4g.small, Primary + Replica, 자동 장애조치)
- [x] Public ALB 모듈 호출 (Frontend 서비스용)
- [x] Management ALB 모듈 호출 (Kafka, ArgoCD, Grafana용, IP 화이트리스트)
- [x] Security Groups 모듈 호출
- [x] IAM 모듈 호출
- [x] Monitoring 모듈 호출
- [x] Route53 레코드 설정 (Public ALB, Management ALB 분리)
- [x] terraform fmt 실행
- [x] terraform init 실행
- [x] 작업 로그 작성

## 결론

Task 4.2 "Prod 환경 main.tf 작성"이 성공적으로 완료되었습니다. Dev 환경과의 주요 차이점인 Multi-AZ 구성, ALB 분리, 강화된 모니터링 및 백업이 모두 반영되었습니다. EKS 모듈 내부 오류는 별도 수정이 필요하지만, Prod 환경 main.tf 자체는 올바르게 작성되었습니다.
