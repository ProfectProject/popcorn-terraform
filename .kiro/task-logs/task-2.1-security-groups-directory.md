# 태스크 2.1: Security Groups 모듈 디렉터리 구조 생성

## 완료 일시
2025-02-08

## 태스크 내용
- modules/security-groups/ 디렉터리 생성
- variables.tf, main.tf, outputs.tf, README.md 파일 생성
- Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 11.6

## 실행 결과

### ✅ 완료된 작업

#### 1. 디렉터리 구조 생성
- `modules/security-groups/` 디렉터리 확인 (이미 존재)
- 필수 파일 4개 생성 완료

#### 2. 생성된 파일

**variables.tf**
- `vpc_id`: VPC ID (필수)
- `environment`: 환경 구분 (dev/prod, 검증 포함)
- `whitelist_ips`: Management ALB 화이트리스트 IP 목록
- `eks_node_security_group_id`: EKS 노드 보안 그룹 ID (선택적)
- `tags`: 리소스 태그

**main.tf**
설계 문서의 요구사항에 맞게 5개 보안 그룹 구현:

1. **Public ALB 보안 그룹**
   - 인터넷(0.0.0.0/0)에서 HTTP(80), HTTPS(443) 접근 허용
   - EKS Node로 모든 포트 아웃바운드 허용

2. **Management ALB 보안 그룹**
   - 화이트리스트 IP에서만 HTTP(80), HTTPS(443) 접근 허용
   - EKS Node로 모든 포트 아웃바운드 허용

3. **EKS Node 보안 그룹 규칙** (선택적)
   - ALB에서 EKS Node로 모든 포트 접근 허용

4. **RDS 보안 그룹**
   - EKS Node에서만 PostgreSQL(5432) 접근 허용

5. **ElastiCache 보안 그룹**
   - EKS Node에서만 Redis/Valkey(6379) 접근 허용

**outputs.tf**
- 각 보안 그룹의 ID와 이름 출력
- ALB, RDS, ElastiCache 모듈에서 참조 가능

**README.md**
- 모듈 개요 및 아키텍처 다이어그램
- 사용 방법 및 예제 (Dev/Prod 환경)
- 입력 변수 및 출력 값 상세 설명
- 보안 그룹 규칙 상세 설명
- 보안 고려사항 및 화이트리스트 관리 가이드
- 트러블슈팅 가이드

### 🎯 요구사항 충족

- ✅ Requirements 7.1: Public ALB 보안 그룹 생성
- ✅ Requirements 7.2: Management ALB 보안 그룹 생성
- ✅ Requirements 7.3: EKS Node 보안 그룹 규칙 생성
- ✅ Requirements 7.4: RDS 보안 그룹 생성
- ✅ Requirements 7.5: ElastiCache 보안 그룹 생성
- ✅ Requirements 7.6: Public ALB 인터넷 접근 허용
- ✅ Requirements 7.7: Management ALB 화이트리스트 IP 접근 허용
- ✅ Requirements 7.8: EKS Node ALB 접근 허용
- ✅ Requirements 7.9: RDS EKS Node 접근 허용
- ✅ Requirements 7.10: ElastiCache EKS Node 접근 허용
- ✅ Requirements 11.6: 모듈 구조 및 문서화 완료

### 📊 검증 결과

- ✅ `terraform fmt -check`: 통과 (코드 포맷 정상)
- ✅ 파일 구조: 4개 파일 모두 생성 완료
- ✅ 최소 권한 원칙 적용
- ✅ 한국어 주석 및 문서 작성

### 📝 보안 그룹 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet (0.0.0.0/0)                   │
└─────────────────┬───────────────────────┬───────────────────┘
                  │                       │
                  │ HTTP/HTTPS            │ HTTP/HTTPS
                  │ (모든 IP)             │ (화이트리스트 IP만)
                  │                       │
        ┌─────────▼─────────┐   ┌────────▼──────────┐
        │  Public ALB SG    │   │ Management ALB SG │
        │  (Frontend)       │   │ (Kafka/ArgoCD/    │
        │                   │   │  Grafana)         │
        └─────────┬─────────┘   └────────┬──────────┘
                  │                      │
                  │ 모든 포트            │ 모든 포트
                  │                      │
        ┌─────────▼──────────────────────▼──────────┐
        │          EKS Node Security Group          │
        │         (EKS 모듈에서 생성)               │
        └─────────┬──────────────────┬───────────────┘
                  │                  │
                  │ 5432             │ 6379
                  │                  │
        ┌─────────▼─────────┐  ┌────▼──────────┐
        │     RDS SG        │  │ ElastiCache SG│
        │  (PostgreSQL)     │  │   (Valkey)    │
        └───────────────────┘  └───────────────┘
```

## 생성된 파일 목록

```
modules/security-groups/
├── variables.tf (신규 생성)
├── main.tf (신규 생성)
├── outputs.tf (신규 생성)
└── README.md (신규 생성)
```

## 다음 단계

태스크 2.2-2.7은 이미 main.tf에 구현되어 있으므로, 태스크 2.8 "Security Groups 모듈 단위 테스트"로 진행
