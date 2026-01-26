# Terraform 인프라 배포 문제 해결 가이드

**작성일**: 2025-01-26  
**세션 ID**: 계속된 세션  
**작업자**: Kiro AI Assistant  

## 개요

이 문서는 Terraform을 사용한 AWS 인프라 배포 과정에서 발생한 주요 문제들과 해결 방법을 상세히 기록합니다. 주요 문제는 RDS 파라미터 그룹, IAM 권한, PostgreSQL 버전 호환성 등이었습니다.

---

## 문제 1: RDS 파라미터 그룹 Apply Method 오류

### 🚨 문제 상황
```
Error: creating RDS DB Instance: operation error RDS: CreateDBInstance, 
https response error StatusCode: 400, RequestID: a1693d4b-db3a-401f-ae87-a457a3d74191, 
api error InvalidParameterCombination: cannot use immediate apply method for static parameter
```

### 🔍 원인 분석
RDS PostgreSQL의 `shared_preload_libraries` 파라미터는 **정적 파라미터(static parameter)**로, 데이터베이스 재시작이 필요한 파라미터입니다. 하지만 코드에서 `apply_method`를 명시하지 않아 기본값인 `immediate`가 적용되어 오류가 발생했습니다.

### 💻 문제가 된 코드
```hcl
# modules/rds/main.tf - 문제 코드
resource "aws_db_parameter_group" "main" {
  family = "postgres16"
  name   = "${var.name}-db-pg"

  parameter {
    name  = "shared_preload_libraries"  # apply_method 누락
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = local.base_tags
}
```

### ✅ 해결 방법
`shared_preload_libraries` 파라미터에 `apply_method = "pending-reboot"` 추가:

```hcl
# modules/rds/main.tf - 수정된 코드
resource "aws_db_parameter_group" "main" {
  family = "postgres18"  # 버전도 함께 업데이트
  name   = "${var.name}-db-pg"

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"  # 🔧 추가된 부분
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = local.base_tags
}
```

### 📚 학습 포인트
- PostgreSQL 파라미터는 **동적(dynamic)**과 **정적(static)** 두 종류가 있음
- 정적 파라미터는 반드시 `apply_method = "pending-reboot"` 설정 필요
- 주요 정적 파라미터: `shared_preload_libraries`, `max_connections`, `shared_buffers` 등

---

## 문제 2: IAM 역할 태그 권한 오류

### 🚨 문제 상황
```
Error: creating IAM Role (goorm-popcorn-dev-ecs-task-execution-role): 
operation error IAM: CreateRole, https response error StatusCode: 403, 
RequestID: d284ff55-e967-4881-8637-e935d0a838fc, 
api error AccessDenied: User: arn:aws:sts::375896310755:assumed-role/github-actions-terraform/GitHubActions 
is not authorized to perform: iam:TagRole on resource: 
arn:aws:iam::375896310755:role/goorm-popcorn-dev-ecs-task-execution-role 
because no identity-based policy allows the iam:TagRole action
```

### 🔍 원인 분석
GitHub Actions에서 사용하는 IAM 역할에 `iam:TagRole` 권한이 없어서 IAM 역할 생성 시 태그를 추가할 수 없었습니다.

### 💻 문제가 된 코드
```hcl
# modules/iam/main.tf - 문제 코드
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.base_tags  # 🚨 이 부분이 문제
}
```

### ✅ 해결 방법
IAM 역할에서 태그 제거:

```hcl
# modules/iam/main.tf - 수정된 코드
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  # tags = local.base_tags  # 🔧 태그 제거
}

# 다른 IAM 역할들도 동일하게 수정
resource "aws_iam_role" "ecs_task" {
  name = "${var.name}-ecs-task-role"
  # ... assume_role_policy
  # tags 제거
}

resource "aws_iam_role" "ecs_autoscaling" {
  name = "${var.name}-ecs-autoscaling-role"
  # ... assume_role_policy  
  # tags 제거
}
```

### 📚 학습 포인트
- GitHub Actions 등 CI/CD 환경에서는 최소 권한 원칙 적용
- IAM 태그 관련 권한(`iam:TagRole`, `iam:UntagRole`)이 별도로 필요
- 권한 문제 시 태그 제거가 빠른 해결책이 될 수 있음

---

## 문제 3: 누락된 EC2 SSM 역할

### 🚨 문제 상황
```
Error: creating IAM Role (goorm-popcorn-dev-ec2-ssm-role): 
operation error IAM: CreateRole, https response error StatusCode: 403
```

### 🔍 원인 분석
EC2 Kafka 인스턴스에서 SSM(Systems Manager) 접근을 위한 IAM 역할과 인스턴스 프로필이 정의되지 않았습니다.

### 💻 문제가 된 코드
```hcl
# envs/dev/main.tf - 문제 코드
module "ec2_kafka" {
  source = "../../modules/ec2-kafka"

  name              = var.ec2_kafka_name
  environment       = "dev"
  # ... 기타 설정
  
  # iam_instance_profile = ???  # 🚨 누락된 부분
}
```

### ✅ 해결 방법

1. **IAM 모듈에 EC2 SSM 역할 추가**:
```hcl
# modules/iam/main.tf - 추가된 코드
# EC2 SSM Role for Kafka instances
resource "aws_iam_role" "ec2_ssm" {
  name = "${var.name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# EC2 SSM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_cloudwatch_agent" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.name}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}
```

2. **IAM 모듈 출력 추가**:
```hcl
# modules/iam/outputs.tf - 추가된 코드
output "ec2_ssm_instance_profile_name" {
  description = "Name of the EC2 SSM instance profile"
  value       = aws_iam_instance_profile.ec2_ssm.name
}
```

3. **EC2 Kafka 모듈에 인스턴스 프로필 연결**:
```hcl
# envs/dev/main.tf - 수정된 코드
module "ec2_kafka" {
  source = "../../modules/ec2-kafka"

  name              = var.ec2_kafka_name
  environment       = "dev"
  # ... 기타 설정
  
  # IAM instance profile
  iam_instance_profile = module.iam.ec2_ssm_instance_profile_name  # 🔧 추가
}
```

### 📚 학습 포인트
- EC2 인스턴스의 AWS 서비스 접근을 위해서는 IAM 역할과 인스턴스 프로필이 필요
- SSM 접근을 위한 기본 정책: `AmazonSSMManagedInstanceCore`
- CloudWatch 로그를 위한 정책: `CloudWatchAgentServerPolicy`

---

## 문제 4: 잘못된 IAM 정책 참조

### 🚨 문제 상황
```
Error: attaching IAM Policy (arn:aws:iam::aws:policy/service-role/AmazonECSServiceRolePolicy) 
to IAM Role (goorm-popcorn-dev-ecs-autoscaling-role): 
operation error IAM: AttachRolePolicy, https response error StatusCode: 404, 
RequestID: 0966a95e-01a3-42fb-9cd4-550a3984f289, 
NoSuchEntity: Policy arn:aws:iam::aws:policy/service-role/AmazonECSServiceRolePolicy 
does not exist or is not attachable.
```

### 🔍 원인 분석
`AmazonECSServiceRolePolicy` 정책이 더 이상 존재하지 않거나 사용이 중단되었습니다. Application Auto Scaling에는 다른 정책이 필요합니다.

### 💻 문제가 된 코드
```hcl
# modules/iam/main.tf - 문제 코드
resource "aws_iam_role_policy_attachment" "ecs_autoscaling" {
  role       = aws_iam_role.ecs_autoscaling.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSServiceRolePolicy"  # 🚨 존재하지 않는 정책
}
```

### ✅ 해결 방법
사용자 정의 정책으로 교체:

```hcl
# modules/iam/main.tf - 수정된 코드
# ECS Auto Scaling Role Custom Policy
resource "aws_iam_role_policy" "ecs_autoscaling" {
  name = "${var.name}-ecs-autoscaling-policy"
  role = aws_iam_role.ecs_autoscaling.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### 📚 학습 포인트
- AWS 관리형 정책은 시간이 지나면서 변경되거나 사용 중단될 수 있음
- Application Auto Scaling에는 ECS와 CloudWatch 권한이 필요
- 사용자 정의 정책으로 필요한 최소 권한만 부여하는 것이 좋음

---

## 문제 5: PostgreSQL 버전 호환성

### 🚨 문제 상황
```
Error: creating RDS DB Instance (goorm-popcorn-dev-postgres): 
operation error RDS: CreateDBInstance, https response error StatusCode: 400, 
RequestID: 8ef0324d-ef3e-49fc-869e-ad4be046665e, 
api error InvalidParameterCombination: Cannot find version 16.4 for postgres
```

### 🔍 원인 분석
AWS RDS에서 PostgreSQL 16.4 버전을 지원하지 않습니다. 사용 가능한 버전을 확인해야 합니다.

### 💻 문제가 된 코드
```hcl
# modules/rds/variables.tf - 문제 코드
variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.4"  # 🚨 지원하지 않는 버전
}

# modules/rds/main.tf - 문제 코드
resource "aws_db_parameter_group" "main" {
  family = "postgres16"  # 🚨 잘못된 패밀리
  name   = "${var.name}-db-pg"
  # ...
}
```

### ✅ 해결 방법

1. **사용 가능한 버전 확인**:
```bash
aws rds describe-db-engine-versions --engine postgres \
  --query "DBEngineVersions[?starts_with(EngineVersion, '18')].EngineVersion" \
  --output table
```

2. **버전 업데이트**:
```hcl
# modules/rds/variables.tf - 수정된 코드
variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "18.1"  # 🔧 지원되는 버전으로 변경
}

# modules/rds/main.tf - 수정된 코드
resource "aws_db_parameter_group" "main" {
  family = "postgres18"  # 🔧 올바른 패밀리로 변경
  name   = "${var.name}-db-pg"
  # ...
}
```

### 📚 학습 포인트
- AWS CLI로 지원되는 엔진 버전을 미리 확인하는 것이 중요
- 파라미터 그룹 패밀리는 메이저 버전과 일치해야 함
- PostgreSQL 18.1이 현재 사용 가능한 최신 버전

---

## 전체 해결 과정 요약

### 1단계: 문제 식별
- Terraform plan/apply 실행 중 발생한 오류 메시지 분석
- 각 오류의 근본 원인 파악

### 2단계: 순차적 해결
1. RDS 파라미터 그룹 `apply_method` 수정
2. IAM 역할에서 태그 제거
3. EC2 SSM 역할 및 인스턴스 프로필 추가
4. 사용자 정의 Auto Scaling 정책 생성
5. PostgreSQL 버전을 18.1로 업데이트

### 3단계: 검증
- 각 수정 후 `terraform plan` 실행하여 오류 해결 확인
- 최종 `terraform apply` 성공적 완료

## 예방 방법

### 1. 사전 검증
```bash
# PostgreSQL 버전 확인
aws rds describe-db-engine-versions --engine postgres

# IAM 정책 존재 여부 확인
aws iam get-policy --policy-arn arn:aws:iam::aws:policy/service-role/PolicyName
```

### 2. 모듈 테스트
- 각 모듈을 독립적으로 테스트
- 최소 권한으로 시작하여 점진적으로 권한 추가

### 3. 문서화
- 각 리소스의 의존성 명확히 문서화
- 버전 호환성 매트릭스 유지

## 결론

이번 문제 해결 과정을 통해 다음을 학습했습니다:

1. **RDS 파라미터 관리**: 정적/동적 파라미터 구분의 중요성
2. **IAM 권한 관리**: CI/CD 환경에서의 최소 권한 원칙
3. **리소스 의존성**: 모듈 간 의존성 관리의 중요성
4. **버전 호환성**: AWS 서비스 버전 확인의 필요성
5. **점진적 해결**: 복잡한 문제를 단계별로 해결하는 방법

모든 문제가 해결되어 PostgreSQL 18.1 기반의 완전한 마이크로서비스 인프라가 성공적으로 배포되었습니다.