# PostgreSQL 업그레이드 가이드 (16.11 → 18.1)

## 개요

이 문서는 AWS RDS PostgreSQL 인스턴스를 16.11 버전에서 18.1 버전으로 업그레이드하는 전체 과정을 기록합니다.

## 업그레이드 정보

- **시작 버전**: PostgreSQL 16.11
- **목표 버전**: PostgreSQL 18.1
- **업그레이드 유형**: Major Version Upgrade
- **환경**: Development (dev)
- **인스턴스**: `goorm-popcorn-dev-postgres`

## 사전 준비사항

### 1. 현재 상태 확인

```bash
# RDS 인스턴스 현재 상태 확인
aws rds describe-db-instances --db-instance-identifier goorm-popcorn-dev-postgres \
  --query 'DBInstances[0].{EngineVersion:EngineVersion,DBParameterGroups:DBParameterGroups}' \
  --output table
```

**결과**: PostgreSQL 16.11, Parameter Group: `goorm-popcorn-dev-db-pg` (postgres16 family)

### 2. 백업 확인

- RDS 자동 백업이 활성화되어 있는지 확인
- 업그레이드 전 자동 백업이 AWS에 의해 생성됨

## 업그레이드 과정

### 단계 1: Terraform 설정 파일 수정

#### 1.1 PostgreSQL 버전 업데이트

**파일**: `popcorn-terraform-feature/envs/dev/terraform.tfvars`

```hcl
# PostgreSQL 엔진 버전 변경
rds_engine_version = "18.1"  # 16.11에서 18.1로 변경
```

#### 1.2 Parameter Group Family 업데이트

**파일**: `popcorn-terraform-feature/modules/rds/main.tf`

```hcl
# 새로운 PostgreSQL 18 Parameter Group 생성
resource "aws_db_parameter_group" "postgres18" {
  family = "postgres18"  # postgres16에서 postgres18로 변경
  name   = "${var.name}-db-pg-18"
  
  # 기존 파라미터 설정 유지
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }
  
  parameter {
    name  = "log_statement"
    value = "all"
  }
  
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
  
  parameter {
    name         = "max_connections"
    value        = "100"
    apply_method = "pending-reboot"
  }
  
  parameter {
    name         = "shared_buffers"
    value        = "{DBInstanceClassMemory/32768}"
    apply_method = "pending-reboot"
  }
  
  tags = local.base_tags
}
```

#### 1.3 RDS 인스턴스 설정 업데이트

**파일**: `popcorn-terraform-feature/modules/rds/main.tf`

```hcl
resource "aws_db_instance" "main" {
  # 엔진 설정
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class
  allow_major_version_upgrade = true  # 중요: Major 버전 업그레이드 허용
  
  # Parameter Group 변경
  parameter_group_name = aws_db_parameter_group.postgres18.name
  
  # 기타 설정...
}
```

### 단계 2: 새 Parameter Group 생성

```bash
# 새 PostgreSQL 18 Parameter Group 먼저 생성
cd popcorn-terraform-feature/envs/dev
terraform apply -target=module.rds.aws_db_parameter_group.postgres18 -auto-approve
```

**결과**: `goorm-popcorn-dev-db-pg-18` Parameter Group 생성 완료

### 단계 3: RDS 인스턴스 업그레이드

#### 3.1 첫 번째 시도 (실패)

```bash
terraform apply -target=module.rds.aws_db_instance.main -auto-approve
```

**오류**: 
```
Error: updating RDS DB Instance: InvalidParameterCombination: 
The AllowMajorVersionUpgrade flag must be present when upgrading to a new major version.
```

#### 3.2 해결책 적용

`allow_major_version_upgrade = true` 설정 추가 후 재시도

```bash
terraform apply -target=module.rds.aws_db_instance.main -auto-approve
```

**결과**: 업그레이드 시작됨 (약 1분 21초 소요)

### 단계 4: 업그레이드 진행 상황 모니터링

#### 4.1 상태 확인

```bash
# 업그레이드 상태 확인
aws rds describe-db-instances --db-instance-identifier goorm-popcorn-dev-postgres \
  --query 'DBInstances[0].{EngineVersion:EngineVersion,DBInstanceStatus:DBInstanceStatus,PendingModifiedValues:PendingModifiedValues}' \
  --output table
```

**진행 상황**:
- `DBInstanceStatus`: `upgrading`
- `PendingModifiedValues`: `"EngineVersion": "18.1"`

#### 4.2 이벤트 로그 확인

```bash
aws rds describe-events --source-identifier goorm-popcorn-dev-postgres \
  --source-type db-instance --max-records 20 \
  --query 'Events[*].{Date:Date,Message:Message}' --output table
```

**주요 이벤트**:
1. `11:21:06` - Pre-check started for DB engine version upgrade
2. `11:21:08` - Pre-check finished for DB engine version upgrade
3. `11:21:09` - DB instance shutdown
4. `11:21:29` - Backing up DB instance
5. `11:24:30` - The engine version upgrade started
6. `11:24:52` - **The engine version upgrade finished**
7. `11:24:52` - The post-upgrade tasks are in progress

### 단계 5: 정리 작업

#### 5.1 기존 Parameter Group 제거

```bash
# 전체 인프라 상태 동기화 및 기존 Parameter Group 제거
terraform apply -auto-approve
```

**결과**: 기존 `goorm-popcorn-dev-db-pg` (PostgreSQL 16) Parameter Group 제거 완료

## 업그레이드 완료 확인

### 최종 상태 검증

```bash
aws rds describe-db-instances --db-instance-identifier goorm-popcorn-dev-postgres \
  --query 'DBInstances[0].{EngineVersion:EngineVersion,DBInstanceStatus:DBInstanceStatus,DBParameterGroups:DBParameterGroups}' \
  --output json
```

**최종 결과**:
```json
{
    "EngineVersion": "18.1",
    "DBInstanceStatus": "available",
    "DBParameterGroups": [
        {
            "DBParameterGroupName": "goorm-popcorn-dev-db-pg-18",
            "ParameterApplyStatus": "in-sync"
        }
    ]
}
```

## 업그레이드 타임라인

| 시간 | 단계 | 소요시간 |
|------|------|----------|
| 11:21:06 | Pre-check 시작 | - |
| 11:21:08 | Pre-check 완료 | 2초 |
| 11:21:09 | DB 인스턴스 종료 | 1초 |
| 11:21:29 | 백업 시작 | 20초 |
| 11:24:30 | 업그레이드 시작 | 3분 1초 |
| 11:24:52 | 업그레이드 완료 | 22초 |
| **총 소요시간** | **약 3분 46초** | |

## 주요 학습 사항

### 1. 필수 설정

- `allow_major_version_upgrade = true` 설정이 반드시 필요
- Parameter Group Family를 새 버전에 맞게 변경 필요

### 2. 업그레이드 순서

1. 새 Parameter Group 생성
2. RDS 인스턴스 업그레이드 (Parameter Group 변경 포함)
3. 기존 Parameter Group 정리

### 3. 모니터링 포인트

- RDS Events를 통한 실시간 진행 상황 확인
- `DBInstanceStatus`와 `PendingModifiedValues` 모니터링
- Parameter Group의 `ParameterApplyStatus` 확인

## 트러블슈팅

### 문제 1: Parameter Group 삭제 실패

**오류**: 
```
InvalidDBParameterGroupState: One or more database instances are still members 
of this parameter group, so the group cannot be deleted
```

**해결책**: 
- RDS 인스턴스가 새 Parameter Group을 사용하도록 먼저 변경
- 기존 Parameter Group 사용이 완전히 중단된 후 삭제

### 문제 2: Major Version Upgrade 플래그 누락

**오류**: 
```
InvalidParameterCombination: The AllowMajorVersionUpgrade flag must be present 
when upgrading to a new major version
```

**해결책**: 
- RDS 인스턴스 리소스에 `allow_major_version_upgrade = true` 추가

## 베스트 프랙티스

1. **사전 백업**: 업그레이드 전 수동 스냅샷 생성 권장
2. **테스트 환경**: 프로덕션 적용 전 개발 환경에서 먼저 테스트
3. **점진적 적용**: Parameter Group 생성 → 인스턴스 업그레이드 → 정리 순서로 진행
4. **모니터링**: 업그레이드 중 RDS Events와 CloudWatch 메트릭 모니터링
5. **롤백 계획**: 문제 발생 시 이전 버전으로 복원할 수 있는 계획 수립

## 참고 자료

- [AWS RDS PostgreSQL 업그레이드 가이드](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_UpgradeDBInstance.PostgreSQL.html)
- [PostgreSQL 18 릴리스 노트](https://www.postgresql.org/docs/18/release-18.html)
- [Terraform AWS RDS 리소스 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance)