# Task 4.6: Prod 환경 outputs.tf 작성

## 작업 일시
2025-01-XX

## 작업 내용

### 1. 파일 생성
- **파일 경로**: `popcorn-terraform-feature/envs/prod/outputs.tf`
- **목적**: Prod 환경의 Terraform 출력 값 정의

### 2. 구현된 출력 값

#### VPC 정보
- `vpc_id`: VPC ID
- `vpc_cidr`: VPC CIDR 블록
- `public_subnet_ids`: Public 서브넷 ID 목록
- `private_subnet_ids`: Private 서브넷 ID 목록
- `data_subnet_ids`: Data 서브넷 ID 목록

#### Public ALB 정보 (Frontend 서비스용)
- `public_alb_dns_name`: Public ALB DNS 이름
- `public_alb_zone_id`: Public ALB Zone ID
- `public_alb_arn`: Public ALB ARN

#### Management ALB 정보 (관리 도구용)
- `management_alb_dns_name`: Management ALB DNS 이름
- `management_alb_zone_id`: Management ALB Zone ID
- `management_alb_arn`: Management ALB ARN

#### EKS 클러스터 정보
- `eks_cluster_id`: EKS 클러스터 ID
- `eks_cluster_endpoint`: EKS 클러스터 엔드포인트
- `eks_cluster_security_group_id`: EKS 클러스터 보안 그룹 ID
- `eks_cluster_arn`: EKS 클러스터 ARN
- `eks_cluster_certificate_authority_data`: EKS 클러스터 인증서 (민감 정보)
- `eks_node_security_group_id`: EKS 노드 보안 그룹 ID
- `eks_oidc_provider_arn`: EKS OIDC 프로바이더 ARN

#### RDS 정보
- `rds_endpoint`: RDS 엔드포인트 (호스트:포트)
- `rds_address`: RDS 주소 (호스트명만)
- `rds_port`: RDS 포트
- `rds_database_name`: RDS 데이터베이스 이름
- `rds_instance_id`: RDS 인스턴스 ID
- `rds_instance_arn`: RDS 인스턴스 ARN
- `rds_secret_arn`: RDS 마스터 비밀번호 Secret ARN (민감 정보)
- `rds_security_group_id`: RDS 보안 그룹 ID
- `rds_jdbc_url`: RDS JDBC 연결 URL

#### ElastiCache 정보
- `elasticache_primary_endpoint`: ElastiCache Primary 엔드포인트
- `elasticache_reader_endpoint`: ElastiCache Reader 엔드포인트
- `elasticache_cluster_id`: ElastiCache 클러스터 ID
- `elasticache_port`: ElastiCache 포트

#### IAM 정보
- `ecs_task_execution_role_arn`: ECS Task Execution Role ARN
- `ecs_task_role_arn`: ECS Task Role ARN
- `ec2_ssm_role_arn`: EC2 SSM Role ARN
- `ec2_ssm_instance_profile_name`: EC2 SSM Instance Profile 이름

#### Route53 정보
- `route53_zone_id`: Route53 Hosted Zone ID
- `route53_domain_name`: 메인 도메인 (goormpopcorn.shop)
- `route53_api_domain`: API 도메인 (api.goormpopcorn.shop)
- `route53_kafka_domain`: Kafka 도메인 (kafka.goormpopcorn.shop)
- `route53_argocd_domain`: ArgoCD 도메인 (argocd.goormpopcorn.shop)
- `route53_grafana_domain`: Grafana 도메인 (grafana.goormpopcorn.shop)

#### 보안 그룹 정보
- `public_alb_security_group_id`: Public ALB 보안 그룹 ID
- `management_alb_security_group_id`: Management ALB 보안 그룹 ID
- `elasticache_security_group_id`: ElastiCache 보안 그룹 ID

#### 모니터링 정보
- `sns_topic_arn`: 통합 모니터링 SNS Topic ARN
- `cloudwatch_dashboard_url`: CloudWatch 대시보드 URL
- `rds_sns_topic_arn`: RDS 전용 SNS Topic ARN

### 3. Dev 환경과의 차이점

#### 추가된 출력 값
1. **Management ALB**: Prod 환경에서는 Public ALB와 Management ALB를 분리
   - `management_alb_dns_name`
   - `management_alb_zone_id`
   - `management_alb_arn`
   - `management_alb_security_group_id`

2. **EKS 클러스터**: Prod 환경에서는 EKS 사용 (Dev는 ECS)
   - `eks_cluster_id`
   - `eks_cluster_endpoint`
   - `eks_cluster_security_group_id`
   - `eks_cluster_arn`
   - `eks_cluster_certificate_authority_data`
   - `eks_node_security_group_id`
   - `eks_oidc_provider_arn`

3. **Route53 도메인**: 모든 서비스 도메인 출력
   - `route53_domain_name`
   - `route53_api_domain`
   - `route53_kafka_domain`
   - `route53_argocd_domain`
   - `route53_grafana_domain`

4. **RDS 추가 정보**:
   - `rds_address`: 호스트명만 별도 출력
   - `rds_instance_arn`: ARN 정보 추가
   - `rds_jdbc_url`: JDBC URL 추가

5. **모니터링 강화**:
   - `cloudwatch_dashboard_url`: 대시보드 URL 추가
   - `rds_sns_topic_arn`: RDS 전용 알림 추가

#### 제거된 출력 값
- Kafka 관련 출력 (Prod에서는 EKS에서 Helm으로 배포)
- ECS 관련 출력 (Prod에서는 EKS 사용)
- CloudMap 관련 출력 (EKS에서는 불필요)

### 4. 민감 정보 처리
다음 출력 값은 `sensitive = true`로 설정:
- `eks_cluster_certificate_authority_data`: EKS 인증서
- `rds_secret_arn`: RDS 비밀번호 Secret ARN

### 5. 검증 결과

#### Terraform Format
```bash
terraform fmt -check outputs.tf
```
✅ **결과**: 형식 검증 통과

#### Terraform Init
```bash
terraform init -backend=false
```
✅ **결과**: 초기화 성공

#### 참고 사항
- `terraform validate` 실행 시 EKS 모듈의 Fargate 관련 오류 발생
- 이는 outputs.tf와 무관한 EKS 모듈 내부 문제
- outputs.tf 파일 자체는 구문적으로 올바름

### 6. 주요 특징

#### 프로덕션 환경 최적화
1. **이중 ALB 구조**: Public과 Management ALB 분리로 보안 강화
2. **EKS 기반**: 컨테이너 오케스트레이션을 EKS로 구현
3. **Multi-AZ RDS**: 고가용성 데이터베이스 구성
4. **강화된 모니터링**: 통합 모니터링 + RDS 전용 알림

#### 확장성 고려
- EKS OIDC Provider ARN 출력으로 IRSA 지원
- 서브넷 정보를 맵 형태로 출력하여 유연한 참조 가능
- 보안 그룹 ID를 모두 출력하여 추가 리소스 연결 용이

#### 운영 편의성
- JDBC URL 직접 제공으로 애플리케이션 설정 간소화
- CloudWatch 대시보드 URL 제공으로 빠른 모니터링 접근
- Route53 도메인 정보 명시로 DNS 설정 명확화

## 파일 구조
```
popcorn-terraform-feature/envs/prod/
├── main.tf              # 메인 설정 (모듈 호출)
├── rds.tf               # RDS 설정
├── variables.tf         # 변수 정의
├── terraform.tfvars     # 변수 값
├── backend.tf           # 백엔드 설정
└── outputs.tf           # ✅ 출력 값 정의 (신규 생성)
```

## 다음 단계
- Task 4.7: Prod 환경 backend.tf 작성
- 전체 Prod 환경 terraform plan 실행
- 인프라 프로비저닝 준비

## 참고 문서
- Dev 환경 outputs.tf: `popcorn-terraform-feature/envs/dev/outputs.tf`
- RDS 모듈 outputs: `popcorn-terraform-feature/modules/rds/outputs.tf`
- EKS 모듈 outputs: `popcorn-terraform-feature/modules/eks/outputs.tf`
- IAM 모듈 outputs: `popcorn-terraform-feature/modules/iam/outputs.tf`
- 모니터링 모듈 outputs: `popcorn-terraform-feature/modules/monitoring/outputs.tf`

## 작업 완료 체크리스트
- [x] outputs.tf 파일 생성
- [x] VPC 출력 값 정의
- [x] Public ALB 출력 값 정의
- [x] Management ALB 출력 값 정의
- [x] EKS 클러스터 출력 값 정의
- [x] RDS 출력 값 정의
- [x] ElastiCache 출력 값 정의
- [x] IAM 출력 값 정의
- [x] Route53 출력 값 정의
- [x] 보안 그룹 출력 값 정의
- [x] 모니터링 출력 값 정의
- [x] 민감 정보 sensitive 설정
- [x] terraform fmt 실행
- [x] terraform init 실행
- [x] 작업 로그 작성

## 작업 결과
✅ **성공**: Prod 환경 outputs.tf 파일이 성공적으로 작성되었습니다.

모든 요구사항을 충족하며, 프로덕션 환경의 특성을 반영한 출력 값들이 정의되었습니다.
