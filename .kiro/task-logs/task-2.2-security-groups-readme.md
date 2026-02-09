# Task 2.2: Security Groups 모듈 README.md 작성

## 작업 일시
2026-02-09

## 작업 내용

Security Groups 모듈의 README.md 파일을 작성하여 모듈 사용 방법, 보안 그룹 목록, 입출력 변수, 보안 고려사항, 트러블슈팅 가이드를 문서화했습니다.

## 파일 경로
`popcorn-terraform-feature/modules/security-groups/README.md`

## 주요 내용

### 1. 모듈 개요
- Goorm Popcorn 프로젝트의 AWS 보안 그룹 관리
- Public ALB, Management ALB, RDS, ElastiCache 보안 그룹 생성

### 2. 아키텍처 다이어그램
- 보안 그룹 간 관계 및 트래픽 흐름 시각화
- Internet → Public ALB → EKS Node → RDS/ElastiCache
- Internet → Management ALB (Whitelist IPs만) → EKS Node

### 3. 보안 그룹 목록

#### Public ALB Security Group
- 이름: `popcorn-{environment}-public-alb-sg`
- Ingress: HTTP (80), HTTPS (443) from 0.0.0.0/0
- Egress: All ports to EKS Node

#### Management ALB Security Group
- 이름: `popcorn-{environment}-management-alb-sg`
- Ingress: HTTP (80), HTTPS (443) from Whitelist IPs만
- Egress: All ports to EKS Node

#### RDS Security Group
- 이름: `popcorn-{environment}-rds-sg`
- Ingress: PostgreSQL (5432) from EKS Node만
- Egress: 없음

#### ElastiCache Security Group
- 이름: `popcorn-{environment}-elasticache-sg`
- Ingress: Redis/Valkey (6379) from EKS Node만
- Egress: 없음

### 4. 사용 방법

#### 기본 사용 예제
```hcl
module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.vpc.vpc_id
  environment = "dev"

  eks_node_security_group_id = module.eks.node_security_group_id

  whitelist_ips = [
    "1.2.3.4/32",  # 사무실 IP
    "5.6.7.8/32"   # VPN IP
  ]

  tags = {
    Environment = "dev"
    Project     = "popcorn"
    ManagedBy   = "terraform"
  }
}
```

#### Dev 환경 예제
- 개발팀 사무실 IP만 화이트리스트에 추가

#### Prod 환경 예제
- 운영팀 사무실 IP 및 VPN 서버 IP를 화이트리스트에 추가

### 5. 입력 변수

| 변수 이름 | 타입 | 필수 | 기본값 | 설명 |
|----------|------|------|--------|------|
| `vpc_id` | string | 예 | - | VPC ID |
| `environment` | string | 예 | - | 환경 이름 (dev/prod) |
| `eks_node_security_group_id` | string | 아니오 | "" | EKS Node Security Group ID |
| `whitelist_ips` | list(string) | 아니오 | [] | Management ALB 접근 허용 IP 목록 |
| `tags` | map(string) | 아니오 | {} | 리소스 태그 |

### 6. 출력 값

| 출력 이름 | 타입 | 설명 |
|----------|------|------|
| `public_alb_sg_id` | string | Public ALB Security Group ID |
| `management_alb_sg_id` | string | Management ALB Security Group ID |
| `rds_sg_id` | string | RDS Security Group ID |
| `elasticache_sg_id` | string | ElastiCache Security Group ID |

### 7. 보안 고려사항

#### 최소 권한 원칙
- 각 보안 그룹은 필요한 최소한의 포트만 개방
- RDS와 ElastiCache는 EKS Node에서만 접근 가능
- Management ALB는 화이트리스트 IP에서만 접근 가능

#### 네트워크 격리
- Public ALB: 인터넷에서 접근 가능 (Frontend만)
- Management ALB: 화이트리스트 IP에서만 접근 가능 (관리 도구)
- RDS/ElastiCache: Private Subnet에 배치, EKS Node에서만 접근

#### 화이트리스트 관리
- Management ALB 접근을 위한 IP는 `whitelist_ips` 변수로 관리
- CIDR 형식으로 지정 (예: `1.2.3.4/32`)
- 환경별로 다른 화이트리스트 적용 가능

#### 보안 그룹 규칙 검증
- Terraform plan 실행 시 보안 그룹 규칙 검토
- Checkov 등 보안 검증 도구 사용 권장

### 8. 의존성

#### 필수 의존성
- VPC 모듈: VPC ID 필요
- EKS 모듈: EKS Node Security Group ID 필요 (선택적)

#### 생성 순서
1. VPC 모듈 생성
2. EKS 모듈 생성 (EKS Node Security Group 생성)
3. Security Groups 모듈 생성
4. ALB 모듈 생성 (Security Groups 모듈의 출력 사용)
5. RDS 모듈 생성 (Security Groups 모듈의 출력 사용)
6. ElastiCache 모듈 생성 (Security Groups 모듈의 출력 사용)

### 9. 트러블슈팅

#### 문제 1: EKS Node에서 RDS 접근 불가
- 원인: RDS Security Group에 EKS Node Security Group Ingress 규칙이 없음
- 해결: `eks_node_security_group_id` 변수 확인, Terraform plan 실행

#### 문제 2: Management ALB 접근 불가
- 원인: 화이트리스트 IP가 올바르게 설정되지 않음
- 해결: `whitelist_ips` 변수에 현재 IP 포함 확인, CIDR 형식 확인

#### 문제 3: Public ALB에서 EKS Node 접근 불가
- 원인: EKS Node Security Group에 ALB Ingress 규칙이 없음
- 해결: `eks_node_security_group_id` 변수 확인, EKS 모듈 출력 확인

### 10. 예제 시나리오

#### 시나리오 1: 새로운 관리자 IP 추가
- `whitelist_ips` 변수에 새로운 IP 추가
- `terraform plan` 및 `terraform apply` 실행

#### 시나리오 2: 환경별 다른 화이트리스트 적용
- Dev 환경: 개발팀 사무실 IP만
- Prod 환경: 운영팀 사무실 IP 및 VPN 서버 IP

### 11. 참고 자료
- AWS Security Groups 공식 문서
- Terraform AWS Security Group 리소스
- AWS Well-Architected Framework - Security Pillar

## 검증

README.md 파일이 다음 내용을 포함하는지 확인:
- [x] 모듈 개요 및 아키텍처 다이어그램
- [x] 보안 그룹 목록 및 규칙 설명
- [x] 사용 방법 및 예제 (기본, Dev, Prod)
- [x] 입력 변수 및 출력 값 테이블
- [x] 보안 고려사항 (최소 권한, 네트워크 격리, 화이트리스트 관리)
- [x] 의존성 및 생성 순서
- [x] 트러블슈팅 가이드
- [x] 예제 시나리오
- [x] 참고 자료

## 다음 단계

Task 2.3: Security Groups 모듈 단위 테스트 실행
- terraform validate
- terraform fmt -check
- checkov 보안 검증

## 참고사항

- README.md는 한국어로 작성되어 개발팀이 쉽게 이해할 수 있도록 함
- 실제 사용 예제를 포함하여 모듈 사용 방법을 명확히 함
- 보안 고려사항을 강조하여 보안 그룹 설정 시 주의사항을 안내
- 트러블슈팅 가이드를 포함하여 문제 발생 시 빠르게 해결할 수 있도록 함
