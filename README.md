# popcorn-terraform

Goorm Popcorn 프로젝트의 AWS 인프라를 Terraform으로 관리합니다.

## 요구사항 및 버전 정책
- Terraform >= 1.4.0
- AWS Provider ~> 5.0
- AWS CLI >= 2.0 (AssumeRole 프로파일 설정 필요)

Terraform과 Provider 버전은 모든 스택에서 동일하게 고정하고,
각 스택의 `versions.tf`로 명시적으로 관리합니다.
공통 템플릿은 `templates/versions.tf`를 사용합니다.

## 디렉토리 구조
```
.
├── bootstrap
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
├── envs
│   ├── dev
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── versions.tf
│   └── prod
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── versions.tf
├── global
│   ├── ecr
│   └── route53-acm
├── modules
│   ├── vpc
│   ├── security-groups
│   ├── ecr
│   ├── route53-acm
│   ├── alb
│   ├── ecs
│   ├── rds
│   ├── elasticache
│   ├── msk
│   ├── cloudmap
│   └── iam
├── templates
│   └── versions.tf
└── docs
```

환경별 값은 `variables.tf`로 선언하고 `terraform.tfvars`에서 주입합니다.

## 주요 특징
- 모듈화: 재사용 가능한 모듈 구조
- 환경 분리: dev/prod 환경 독립 관리, 전역 리소스 분리
- 보안: 최소 권한 원칙, SG 계층 분리
- 확장성: Multi-AZ 기반으로 확장 가능한 구조
- 비용 최적화: NAT 미도입/Endpoint 도입 전략, 환경별 리소스 차등

## 현재 구성된 리소스 (코드 기준)
- VPC 및 서브넷 (3-Tier)
- Security Group (ALB/ECS/DB/Cache/Kafka)
- ECR 레포지토리
- Route53 Hosted Zone + ACM 인증서 (global)

## GitHub Actions (CI/CD)
- PR(`develop`/`main`)에서 `terraform plan` 실행 후 PR 코멘트로 출력
- `develop` 머지 시 dev 환경 `terraform apply`
- `main` 머지 시 prod 환경 `terraform apply`

## Terraform backend 구성
1) backend 리소스 생성 (최초 1회)
```bash
cd bootstrap
terraform init
terraform apply -var="project_name=goorm-popcorn"
```
이미 생성되어 있다면 팀원들은 이 단계 없이 진행합니다.

2) 환경별 backend 설정 파일
- `envs/dev/backend.tf`
- `envs/prod/backend.tf`
- `global/route53-acm/backend.tf`
- `global/ecr/backend.tf`

## 실행 흐름
1) global 스택 (전역 리소스)
```bash
cd global/route53-acm
terraform init
terraform plan
terraform apply
```

```bash
cd global/ecr
terraform init
terraform plan
terraform apply
```

2) dev 스택
```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

3) prod 스택
```bash
cd envs/prod
terraform init
terraform plan
terraform apply
```

## 환경별 차이 (예시 기준)
dev와 prod는 동일한 모듈을 쓰고, 환경별 값만 다르게 적용합니다.

- NAT Gateway 수: dev 1개(또는 미도입) / prod 2개(AZ별)
- Aurora 인스턴스 수: dev 최소 1 / prod 2 이상
- ElastiCache 노드 수: dev 1 / prod 2 이상
- Auto Scaling: dev 최소/비활성화 / prod 활성

## 참고
- `terraform.tfstate`는 커밋하지 않습니다.
- 실행 시 `AWS_PROFILE=terraform` 사용을 권장합니다.
