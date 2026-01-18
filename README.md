# popcorn-terraform

Popcorn 프로젝트의 AWS 인프라를 Terraform으로 관리합니다.

## 요구사항
- Terraform >= 1.4.0
- AWS CLI (AssumeRole 프로파일 설정 필요)

## 구조
- `bootstrap/` : Terraform backend용 S3 + DynamoDB 생성
- `modules/`   : 공통 인프라 모듈
- `envs/`      : 환경별 스택 (dev/prod)

## 시작 방법
1) backend 리소스 생성
```bash
cd bootstrap
terraform init
terraform apply -var="project_name=goorm-popcorn"
```

2) 환경별 backend 설정
- `envs/dev/backend.tf`
- `envs/prod/backend.tf`

3) 환경별 실행
```bash
cd envs/dev
terraform init
terraform plan
```

## 참고
- `terraform.tfstate`는 커밋하지 않습니다.
- 실행 시 `AWS_PROFILE=terraform` 사용을 권장합니다.
