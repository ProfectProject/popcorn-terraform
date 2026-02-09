# Terraform 인프라 리팩토링 완료 체크리스트

## 개요

이 문서는 Terraform 인프라 리팩토링 프로젝트의 모든 요구사항이 충족되었는지 확인하는 체크리스트입니다.

## 1. 환경별 인프라 구성

### Dev 환경
- [x] 단일 AZ (ap-northeast-2a) 구성
- [x] VPC (10.0.0.0/16) 생성
- [x] Public, Private, Data 서브넷 생성
- [x] 단일 NAT Gateway 구성
- [x] EKS 클러스터 (Kubernetes 1.35) 생성
- [x] EKS 노드 그룹 (t3.medium, 2-5 노드) 구성
- [x] RDS PostgreSQL (db.t4g.micro, 단일 AZ, 1일 백업) 생성
- [x] ElastiCache Valkey (cache.t4g.micro, 단일 노드) 생성
- [x] Public ALB 생성
- [x] Management ALB 생성

### Prod 환경
- [x] Multi-AZ (ap-northeast-2a, ap-northeast-2c) 구성
- [x] VPC (10.0.0.0/16) 생성
- [x] Public, Private, Data 서브넷 생성 (각 AZ)
- [x] Multi-AZ NAT Gateway 구성
- [x] EKS 클러스터 (Kubernetes 1.35) 생성
- [x] EKS 노드 그룹 (t3.medium~large, 3-5 노드) 구성
- [x] RDS PostgreSQL (db.t4g.micro, Multi-AZ, 7일 백업, Performance Insights) 생성
- [x] ElastiCache Valkey (cache.t4g.small, Primary + Replica, 자동 장애조치) 생성
- [x] Public ALB 생성
- [x] Management ALB 생성

## 2. VPC 및 네트워크

- [x] VPC CIDR 블록 (10.0.0.0/16)
- [x] Public Subnet (인터넷 게이트웨이 연결)
- [x] Private App Subnet (NAT Gateway 연결)
- [x] Private Data Subnet (NAT Gateway 연결)
- [x] NAT Gateway (Public Subnet 배치)
- [x] VPC Endpoints (ECR, S3, Secrets Manager)
- [x] VPC Flow Logs (CloudWatch Logs)

## 3. EKS 클러스터

- [x] Kubernetes 1.35 버전
- [x] Control Plane 로그 활성화
- [x] Secrets 암호화 (KMS)
- [x] 환경별 노드 구성 (Dev: t3.medium 2-5, Prod: t3.medium~large 3-5)
- [x] EBS CSI Driver 설치
- [x] AWS Load Balancer Controller IRSA
- [x] Cluster Autoscaler IRSA
- [x] Helm Provider 설정

## 4. RDS PostgreSQL

- [x] PostgreSQL 16.1
- [x] 환경별 인스턴스 클래스 (Dev: db.t4g.micro, Prod: db.t4g.micro)
- [x] 환경별 Multi-AZ (Dev: 단일 AZ, Prod: Multi-AZ)
- [x] 환경별 백업 보존 기간 (Dev: 1일, Prod: 7일)
- [x] 저장 시 암호화 (AES-256)
- [x] 전송 중 암호화 (TLS)
- [x] Secrets Manager 자격증명 관리
- [x] Performance Insights (Prod만)
- [x] CloudWatch 로그 수집
- [x] CloudWatch 알람

## 5. ElastiCache Valkey

- [x] Valkey 7.1
- [x] 환경별 노드 타입 (Dev: cache.t4g.micro, Prod: cache.t4g.small)
- [x] 환경별 노드 수 (Dev: 1, Prod: 2)
- [x] 전송 중 암호화
- [x] 자동 장애조치 (Prod만)
- [x] 일일 백업 (Prod만)
- [x] CloudWatch 메트릭 수집

## 6. ALB (Application Load Balancer)

- [x] Public ALB 생성 (외부 사용자 접근)
- [x] Management ALB 생성 (관리 도구 접근)
- [x] HTTPS 리스너 (ACM 인증서)
- [x] HTTP to HTTPS 리다이렉트
- [x] Public ALB 도메인 연결 (goormpopcorn.shop)
- [x] Management ALB 도메인 연결 (kafka, argocd, grafana)
- [x] Management ALB IP 화이트리스트
- [x] CloudWatch 메트릭 수집
- [x] CloudWatch 알람

## 7. Security Groups

- [x] Public ALB Security Group (0.0.0.0/0 → 80, 443)
- [x] Management ALB Security Group (화이트리스트 IP → 80, 443)
- [x] EKS Cluster Security Group
- [x] EKS Node Security Group (ALB → 모든 포트)
- [x] RDS Security Group (EKS Node → 5432)
- [x] ElastiCache Security Group (EKS Node → 6379)
- [x] 최소 권한 원칙 적용

## 8. IAM 역할 및 정책

- [x] EKS Cluster Service Role
- [x] EKS Node Group Role
- [x] Karpenter IRSA (선택적)
- [x] AWS Load Balancer Controller IRSA
- [x] EBS CSI Driver IRSA
- [x] Cluster Autoscaler IRSA
- [x] 서비스별 IRSA (Secrets Manager, S3)
- [x] 최소 권한 원칙 적용

## 9. Route53 DNS

- [x] goormpopcorn.shop → Public ALB
- [x] kafka.goormpopcorn.shop → Management ALB
- [x] argocd.goormpopcorn.shop → Management ALB
- [x] grafana.goormpopcorn.shop → Management ALB
- [x] 헬스체크 구성

## 10. CloudWatch 모니터링

- [x] EKS 클러스터 로그 수집
- [x] RDS 메트릭 수집
- [x] ElastiCache 메트릭 수집
- [x] ALB 메트릭 수집
- [x] VPC Flow Logs
- [x] CloudWatch 알람 (RDS CPU, ALB 5xx)
- [x] SNS 알림

## 11. 모듈화

- [x] VPC 모듈
- [x] EKS 모듈
- [x] RDS 모듈
- [x] ElastiCache 모듈
- [x] ALB 모듈 (신규 작성)
- [x] Security Groups 모듈 (신규 작성)
- [x] IAM 모듈
- [x] Monitoring 모듈
- [x] 모듈 README 작성

## 12. Terraform 백엔드

- [x] S3 백엔드 설정 (Dev: goorm-popcorn-tfstate, Prod: popcorn-terraform-state)
- [x] DynamoDB 잠금 테이블
- [x] 환경별 State 키 (dev/terraform.tfstate, prod/terraform.tfstate)
- [x] State 파일 암호화

## 13. 비용 최적화

- [x] Dev 환경 단일 NAT Gateway
- [x] Dev 환경 작은 인스턴스 타입
- [x] Prod 환경 Karpenter 설정 (선택적)
- [x] VPC Endpoints (NAT Gateway 트래픽 절감)
- [x] 리소스 태그 (Environment, Project, ManagedBy)
- [x] S3 라이프사이클 정책 (로그 자동 삭제)

## 14. 보안

- [x] 모든 데이터 전송 TLS 암호화
- [x] 모든 저장 데이터 AES-256 암호화
- [x] Secrets Manager 자격증명 관리
- [x] 보안 그룹 최소 권한 원칙
- [x] IAM 최소 권한 원칙
- [x] Management ALB IP 화이트리스트
- [x] VPC Flow Logs 활성화

## 15. 고가용성

- [x] Prod 환경 Multi-AZ 구성
- [x] RDS Multi-AZ (Prod)
- [x] ElastiCache 자동 장애조치 (Prod)
- [x] ALB Multi-AZ
- [x] EKS Node Multi-AZ
- [x] NAT Gateway Multi-AZ (Prod)

## 16. GitHub Actions

- [x] Dev 환경 워크플로우 작성
- [x] Prod 환경 워크플로우 작성
- [x] PR 생성 시 terraform plan 실행
- [x] PR 머지 시 terraform apply 실행
- [x] GitHub Secrets 설정 가이드
- [x] Prod 환경 수동 승인
- [x] Concurrency 설정 (동시 실행 방지)
- [x] DynamoDB 잠금 설정

## 17. 속성 검증

- [x] 속성 검증 스크립트 작성 (33개 속성)
- [x] 환경별 AZ 구성 검증
- [x] VPC 및 서브넷 구성 검증
- [x] EKS 구성 검증
- [x] RDS 구성 검증
- [x] ElastiCache 구성 검증
- [x] ALB 구성 검증
- [x] Security Groups 검증
- [x] IAM 역할 검증
- [x] 모니터링 검증
- [x] 비용 최적화 검증
- [x] 보안 및 고가용성 검증

## 18. 테스트

- [x] Terraform validate 통과 (Dev)
- [x] Terraform validate 통과 (Prod)
- [x] Terraform fmt -check 통과 (Dev)
- [x] Terraform fmt -check 통과 (Prod)
- [x] 속성 검증 스크립트 구조 테스트 통과

## 19. 문서화

- [x] ALB 모듈 README
- [x] Security Groups 모듈 README
- [x] 환경별 배포 가이드
- [x] GitHub Actions 사용 가이드
- [x] 트러블슈팅 가이드
- [x] 완료 체크리스트

## 20. 코드 품질

- [x] 모든 Terraform 코드 한국어 주석
- [x] 변수 타입 및 설명 명시
- [x] 출력 값 설명 명시
- [x] 모듈 간 의존성 명확화
- [x] 리소스 태그 일관성

## 최종 확인

### 필수 확인 사항
- [x] 모든 요구사항 충족
- [x] 모든 테스트 통과
- [x] 모든 문서 작성 완료
- [x] 코드 리뷰 완료 (필요시)

### 배포 준비
- [ ] AWS 자격증명 설정
- [ ] GitHub Secrets 설정
- [ ] S3 백엔드 버킷 생성
- [ ] DynamoDB 테이블 생성
- [ ] ACM 인증서 발급
- [ ] Route53 호스팅 존 생성

### 배포 후 확인
- [ ] Dev 환경 배포 성공
- [ ] Prod 환경 배포 성공
- [ ] 모든 리소스 정상 동작
- [ ] CloudWatch 메트릭 수집 확인
- [ ] 알람 정상 동작 확인

## 결론

✅ **모든 요구사항이 충족되었습니다!**

Terraform 인프라 리팩토링 프로젝트가 성공적으로 완료되었습니다. 이제 Dev 및 Prod 환경에 배포할 준비가 되었습니다.

## 다음 단계

1. AWS 자격증명 및 GitHub Secrets 설정
2. Dev 환경 배포 및 테스트
3. Prod 환경 배포 및 검증
4. 모니터링 및 알람 확인
5. 팀원 교육 및 문서 공유

## 지원

문제가 발생하면 DevOps 팀에 문의하세요:
- Slack: #devops-support
- Email: devops@goorm.io

