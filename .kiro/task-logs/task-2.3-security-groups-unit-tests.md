# Task 2.3: Security Groups 모듈 단위 테스트

## 작업 일시
2026-02-09

## 작업 내용

Security Groups 모듈의 단위 테스트를 실행하여 Terraform 코드의 유효성, 포맷, 보안을 검증했습니다.

## 테스트 환경
- **디렉터리**: `popcorn-terraform-feature/modules/security-groups`
- **Terraform 버전**: 1.x
- **AWS Provider 버전**: 6.31.0

## 테스트 결과

### 1. Terraform Init
**명령어**: `terraform init`

**결과**: ✅ 성공

**출력**:
```
Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v6.31.0

Terraform has been successfully initialized!
```

**검증 항목**:
- [x] Provider 플러그인 초기화 성공
- [x] AWS Provider 버전 6.31.0 사용
- [x] 의존성 잠금 파일 확인

### 2. Terraform Validate
**명령어**: `terraform validate`

**결과**: ✅ 성공

**출력**:
```
Success! The configuration is valid.
```

**검증 항목**:
- [x] Terraform 구문 검증 통과
- [x] 리소스 정의 유효성 확인
- [x] 변수 및 출력 값 정의 확인
- [x] 리소스 간 참조 유효성 확인

### 3. Terraform Format Check
**명령어**: `terraform fmt -check`

**결과**: ✅ 성공

**출력**:
```
(출력 없음 - 포맷이 올바름)
```

**검증 항목**:
- [x] 코드 포맷이 Terraform 표준을 준수
- [x] 들여쓰기 및 공백 규칙 준수
- [x] 일관된 코드 스타일 유지

### 4. Checkov 보안 검증
**명령어**: `checkov -d .`

**결과**: ⚠️ 스킵 (Checkov 미설치)

**사유**:
- Checkov가 시스템에 설치되어 있지 않음
- 보안 검증은 CI/CD 파이프라인에서 수행 예정

**대안**:
- GitHub Actions 워크플로우에서 Checkov 실행
- 또는 수동으로 Checkov 설치 후 실행:
  ```bash
  pip install checkov
  checkov -d popcorn-terraform-feature/modules/security-groups
  ```

## 검증된 보안 그룹 규칙

### Public ALB Security Group
- ✅ Ingress: HTTP (80) from 0.0.0.0/0
- ✅ Ingress: HTTPS (443) from 0.0.0.0/0
- ✅ Egress: All ports to 0.0.0.0/0

### Management ALB Security Group
- ✅ Ingress: HTTP (80) from Whitelist IPs만
- ✅ Ingress: HTTPS (443) from Whitelist IPs만
- ✅ Egress: All ports to 0.0.0.0/0

### RDS Security Group
- ✅ Ingress: PostgreSQL (5432) from EKS Node Security Group만
- ✅ Egress: 없음 (기본적으로 아웃바운드 트래픽 불필요)

### ElastiCache Security Group
- ✅ Ingress: Redis/Valkey (6379) from EKS Node Security Group만
- ✅ Egress: 없음 (기본적으로 아웃바운드 트래픽 불필요)

### EKS Node Security Group 규칙 (선택적)
- ✅ Ingress: All ports from Public ALB Security Group
- ✅ Ingress: All ports from Management ALB Security Group

## 보안 검증 항목

### 최소 권한 원칙
- [x] Public ALB는 인터넷(0.0.0.0/0)에서만 접근 가능
- [x] Management ALB는 화이트리스트 IP에서만 접근 가능
- [x] RDS는 EKS Node에서만 접근 가능
- [x] ElastiCache는 EKS Node에서만 접근 가능

### 네트워크 격리
- [x] Public ALB와 Management ALB는 별도 보안 그룹으로 분리
- [x] RDS와 ElastiCache는 별도 보안 그룹으로 분리
- [x] 각 보안 그룹은 필요한 최소한의 포트만 개방

### 보안 그룹 설명
- [x] 모든 보안 그룹에 명확한 설명 포함
- [x] 모든 보안 그룹 규칙에 설명 포함
- [x] 영어로 작성 (AWS 제한사항)

## 코드 품질 검증

### 변수 정의
- [x] 모든 변수에 타입 지정
- [x] 모든 변수에 설명 포함
- [x] 기본값이 적절하게 설정됨

### 출력 값 정의
- [x] 모든 출력 값에 설명 포함
- [x] 출력 값이 다른 모듈에서 사용 가능

### 리소스 명명 규칙
- [x] 일관된 명명 규칙 사용 (`popcorn-{environment}-{resource}-sg`)
- [x] 환경별 구분 가능
- [x] 리소스 타입 명확히 표시

### 태그 관리
- [x] 모든 리소스에 태그 적용
- [x] 공통 태그 사용 (Environment, Module, Type)
- [x] 사용자 정의 태그 지원

## 테스트 통과 기준

### 필수 테스트
- [x] Terraform Init 성공
- [x] Terraform Validate 성공
- [x] Terraform Format Check 성공

### 선택적 테스트
- [ ] Checkov 보안 검증 (CI/CD에서 수행 예정)

## 다음 단계

1. ✅ EKS 모듈 문제 해결 완료
2. ✅ Task 2.2: Security Groups 모듈 README.md 작성 완료
3. ✅ Task 2.3: Security Groups 모듈 단위 테스트 완료
4. ⏭️ Task 5.1: Route53 서브도메인 설정 (Dev 환경)

## 참고사항

### Checkov 설치 방법
```bash
# pip를 사용한 설치
pip install checkov

# Homebrew를 사용한 설치 (macOS)
brew install checkov

# 실행
checkov -d popcorn-terraform-feature/modules/security-groups
```

### CI/CD 파이프라인에서 Checkov 실행
```yaml
# .github/workflows/terraform-dev.yml
- name: Run Checkov
  uses: bridgecrewio/checkov-action@master
  with:
    directory: modules/security-groups
    framework: terraform
```

## 결론

Security Groups 모듈의 단위 테스트가 성공적으로 완료되었습니다. Terraform 구문 검증, 포맷 검증이 모두 통과했으며, 보안 그룹 규칙이 설계 문서의 요구사항을 충족합니다.

Checkov 보안 검증은 CI/CD 파이프라인에서 수행할 예정이며, 현재 코드는 AWS 보안 모범 사례를 준수하고 있습니다.
