# Terraform 배포 문제 해결 가이드

이 문서는 popcorn-terraform-feature 프로젝트 배포 과정에서 발생한 문제들과 해결 방법을 정리합니다.

## 목차
1. [AWS RDS 관련 문제](#aws-rds-관련-문제)
2. [네트워크 및 상태 관리 문제](#네트워크-및-상태-관리-문제)
3. [PostgreSQL 버전 관련 문제](#postgresql-버전-관련-문제)

---

## AWS RDS 관련 문제

### 1. ALB Multi-AZ 요구사항 문제

**문제 상황:**
```
Error: creating ELBv2 application Load Balancer: At least two subnets in two different Availability Zones must be specified
```

**원인:**
- AWS Application Load Balancer는 고가용성을 위해 최소 2개의 서로 다른 AZ에 서브넷이 필요
- 개발 환경에서 비용 절약을 위해 단일 AZ 구성을 시도했으나 ALB 요구사항과 충돌

**해결 방법:**
```hcl
# terraform.tfvars
public_subnets = [
  {
    name = "goorm-popcorn-dev-public-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.1.0/24"
  },
  {
    name = "goorm-popcorn-dev-public-2c"  # 추가된 AZ
    az   = "ap-northeast-2c"
    cidr = "10.0.2.0/24"
  }
]
```

### 2. RDS DB Subnet Group Multi-AZ 요구사항

**문제 상황:**
```
Error: creating RDS DB Subnet Group: The DB subnet group doesn't meet Availability Zone (AZ) coverage requirement. Current AZ coverage: ap-northeast-2a. Add subnets to cover at least 2 AZs.
```

**원인:**
- AWS RDS DB Subnet Group은 `multi_az = false` 설정과 관계없이 최소 2개 AZ에 서브넷이 필요
- 이는 AWS의 정책적 요구사항으로 변경 불가능

**해결 방법:**
```hcl
# terraform.tfvars
data_subnets = [
  {
    name = "goorm-popcorn-dev-data-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.21.0/24"
  },
  {
    name = "goorm-popcorn-dev-data-2c"  # RDS 요구사항을 위해 추가
    az   = "ap-northeast-2c"
    cidr = "10.0.22.0/24"
  }
]
```

**중요 사항:**
- DB Subnet Group: 최소 2개 AZ 필요 (AWS 정책)
- Multi-AZ 설정: 실제 인스턴스 복제 여부 (사용자 선택)
- 비용 영향: Data 서브넷 자체는 무료, 실제 인스턴스는 `multi_az = false`로 단일 AZ에서 실행

---

## 네트워크 및 상태 관리 문제

### 3. Terraform 상태 저장 실패

**문제 상황:**
```
Error: Failed to save state: failed to upload state: RequestError: send request failed
caused by: Put "https://goorm-popcorn-tfstate.s3.ap-northeast-2.amazonaws.com/dev/terraform.tfstate": dial tcp: lookup goorm-popcorn-tfstate.s3.ap-northeast-2.amazonaws.com: no such host
```

**원인:**
- 네트워크 연결 문제로 인한 DNS 조회 실패
- Terraform apply 중 상태 저장 실패로 `errored.tfstate` 파일 생성
- 상태 락(State Lock)이 걸린 상태

**해결 방법:**
1. **상태 락 강제 해제:**
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **에러 상태 파일 복구:**
   ```bash
   terraform state push errored.tfstate
   ```

3. **에러 파일 정리:**
   ```bash
   rm errored.tfstate
   ```

**예방 방법:**
- 안정적인 네트워크 환경에서 배포 실행
- 배포 전 AWS 자격 증명 및 네트워크 연결 확인

---

## PostgreSQL 버전 관련 문제

### 4. PostgreSQL 버전 호환성 문제

**문제 상황:**
```
Error: creating RDS DB Instance: Cannot find version 16.4 for postgres
```

**원인:**
- 지정한 PostgreSQL 버전이 AWS RDS에서 지원되지 않음
- AWS RDS는 특정 버전만 지원하며, 지원 버전은 지역별로 다를 수 있음

**해결 방법:**
1. **사용 가능한 버전 확인:**
   ```bash
   aws rds describe-db-engine-versions --engine postgres --query 'DBEngineVersions[].EngineVersion' --output table | grep "16\."
   ```

2. **지원되는 버전으로 변경:**
   ```hcl
   # terraform.tfvars
   rds_engine_version = "16.11"  # 사용 가능한 버전으로 변경
   ```

### 5. DB Parameter Group Family 불일치

**문제 상황:**
```
Error: modifying RDS DB Parameter Group: cannot use immediate apply method for static parameter
```

**원인:**
- PostgreSQL 버전 변경 시 Parameter Group family 불일치
- Static parameter에 대해 잘못된 apply method 사용

**해결 방법:**
1. **Parameter Group family 업데이트:**
   ```hcl
   resource "aws_db_parameter_group" "main" {
     family = "postgres18"  # 버전에 맞게 변경
     
     parameter {
       name         = "max_connections"
       value        = "100"
       apply_method = "pending-reboot"  # static parameter는 pending-reboot 사용
     }
   }
   ```

2. **Apply method 구분:**
   - **Dynamic parameters**: `apply_method = "immediate"`
   - **Static parameters**: `apply_method = "pending-reboot"`

---

## 최종 권장 구성

### 개발 환경 최적화 구성
```hcl
# 비용 최적화와 AWS 요구사항을 모두 만족하는 구성
public_subnets = [
  # ALB 요구사항: 2개 AZ
  { name = "dev-public-2a", az = "ap-northeast-2a", cidr = "10.0.1.0/24" },
  { name = "dev-public-2c", az = "ap-northeast-2c", cidr = "10.0.2.0/24" }
]

private_subnets = [
  # ECS 실행: 단일 AZ (비용 절약)
  { name = "dev-private-2a", az = "ap-northeast-2a", cidr = "10.0.11.0/24" }
]

data_subnets = [
  # RDS DB Subnet Group 요구사항: 2개 AZ
  { name = "dev-data-2a", az = "ap-northeast-2a", cidr = "10.0.21.0/24" },
  { name = "dev-data-2c", az = "ap-northeast-2c", cidr = "10.0.22.0/24" }
]

# RDS 설정
multi_az = false  # 실제 인스턴스는 단일 AZ에서 실행
single_nat_gateway = true  # NAT Gateway 1개만 사용
```

### 트래픽 흐름
```
Internet → Route53 → ALB (2a + 2c) → ECS (2a만) → 내부 서비스들
                                   ↓
                              RDS (2a + 2c 서브넷, 실제 인스턴스는 2a)
```

---

## 체크리스트

배포 전 확인사항:
- [ ] AWS 자격 증명 설정 확인
- [ ] 네트워크 연결 상태 확인
- [ ] PostgreSQL 버전 지원 여부 확인
- [ ] Parameter Group family와 엔진 버전 일치 확인
- [ ] 서브넷 AZ 구성이 AWS 요구사항 충족 확인

배포 후 확인사항:
- [ ] ALB DNS 이름 정상 동작 확인
- [ ] Route53 레코드 연결 확인
- [ ] ECS 서비스 상태 확인
- [ ] RDS 인스턴스 연결 확인
- [ ] CloudMap 서비스 디스커버리 동작 확인

---

## 참고 자료

- [AWS RDS DB Subnet Groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html)
- [AWS Application Load Balancer Requirements](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
- [AWS RDS PostgreSQL Versions](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)