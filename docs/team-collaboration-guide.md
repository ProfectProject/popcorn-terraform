# Terraform 팀 협업 가이드

## 📋 개요

Goorm Popcorn 프로젝트에서 여러 개발자가 Terraform을 안전하고 일관성 있게 사용하기 위한 가이드입니다.

## 🔧 **tfvars 파일 관리 원칙**

### **1. 파일 구조**
```
envs/dev/
├── terraform.tfvars.example    # ✅ Git 커밋 (공유 템플릿)
├── terraform.tfvars           # ❌ Git 무시 (개인 설정)
├── variables.tf               # ✅ Git 커밋 (변수 정의)
└── main.tf                    # ✅ Git 커밋 (인프라 정의)
```

### **2. 보안 원칙**
- **절대 금지**: `terraform.tfvars` 파일을 Git에 커밋
- **필수**: 민감한 정보는 AWS Secrets Manager 사용
- **권장**: 개인별 다른 리소스 이름 사용 (충돌 방지)

## 🚀 **개발자 온보딩**

### **1. 초기 설정**
```bash
# 1. 프로젝트 클론
git clone https://github.com/your-org/popcorn-terraform-feature.git
cd popcorn-terraform-feature/envs/dev

# 2. 개인 설정 파일 생성
cp terraform.tfvars.example terraform.tfvars

# 3. 개인 환경에 맞게 수정
vim terraform.tfvars
```

### **2. 필수 수정 항목**
```hcl
# terraform.tfvars에서 반드시 수정해야 할 값들

# 1. ECR Repository URL (Global ECR 배포 후 확인)
ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com"

# 2. EC2 Key Pair (개인별 생성)
ec2_kafka_key_name = "your-name-keypair"

# 3. 리소스 이름 (개인별 구분)
vpc_name = "goorm-popcorn-vpc-dev-yourname"
rds_name = "goorm-popcorn-dev-yourname"
ecs_name = "goorm-popcorn-dev-yourname"
# ... 기타 리소스들
```

### **3. AWS 리소스 준비**
```bash
# 개인 키페어 생성
aws ec2 create-key-pair \
  --key-name your-name-keypair \
  --region ap-northeast-2 \
  --output text --query 'KeyMaterial' > ~/.ssh/your-name-keypair.pem
chmod 400 ~/.ssh/your-name-keypair.pem

# ECR URL 확인
aws ecr describe-repositories --region ap-northeast-2
```

## 🔄 **일상 워크플로우**

### **1. 변경사항 적용**
```bash
# 1. 최신 코드 가져오기
git pull origin develop

# 2. 변경사항 확인
terraform plan

# 3. 적용 (신중하게!)
terraform apply

# 4. 상태 확인
terraform show
```

### **2. 새로운 변수 추가 시**
```bash
# 1. variables.tf에 변수 정의 추가
# 2. terraform.tfvars.example에 예시 값 추가
# 3. 팀에 공지 (Slack, PR 등)
# 4. 각자 terraform.tfvars 업데이트
```

## 🚨 **충돌 방지 전략**

### **1. 리소스 이름 규칙**
```hcl
# 개발 환경에서는 개인별 구분자 사용
vpc_name = "goorm-popcorn-vpc-dev-${개발자이름}"
rds_name = "goorm-popcorn-dev-${개발자이름}"

# 예시
vpc_name = "goorm-popcorn-vpc-dev-john"
rds_name = "goorm-popcorn-dev-john"
```

### **2. 상태 파일 분리**
```bash
# 개인 개발용 별도 백엔드 설정 (선택사항)
# backend.tf
terraform {
  backend "s3" {
    bucket = "goorm-popcorn-tfstate"
    key    = "dev-${개발자이름}/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
```

### **3. 동시 작업 방지**
```bash
# 작업 전 팀에 공지
# Slack: "dev 환경 terraform 작업 시작합니다 (30분 예상)"

# 작업 완료 후 공지
# Slack: "dev 환경 terraform 작업 완료했습니다"
```

## 🔐 **보안 가이드라인**

### **1. 민감 정보 관리**
```hcl
# ❌ 절대 금지
password = "mypassword123"

# ✅ 권장 방법
password = data.aws_secretsmanager_secret_version.db_password.secret_string
```

### **2. .gitignore 확인**
```bash
# 다음 파일들이 .gitignore에 있는지 확인
*.tfvars
!*.tfvars.example
.terraform/
.terraform.lock.hcl
terraform.tfstate*
*.backup
```

### **3. 실수 방지**
```bash
# 커밋 전 항상 확인
git status
git diff --cached

# tfvars 파일이 포함되어 있다면 즉시 제거
git reset HEAD terraform.tfvars
```

## 📊 **환경별 관리 전략**

### **개발 환경 (dev)**
- **목적**: 개인 개발 및 테스트
- **리소스**: 최소 사양 (비용 절약)
- **데이터**: 테스트 데이터만
- **백업**: 불필요

### **운영 환경 (prod)**
- **목적**: 실제 서비스 운영
- **리소스**: 고가용성 구성
- **데이터**: 실제 고객 데이터
- **백업**: 필수

## 🔧 **트러블슈팅**

### **1. 상태 잠금 오류**
```bash
# 다른 개발자가 작업 중인 경우
terraform force-unlock LOCK_ID

# 주의: 실제로 다른 사람이 작업 중이 아닌지 확인 후 실행
```

### **2. 리소스 충돌**
```bash
# 리소스 이름이 중복된 경우
# terraform.tfvars에서 고유한 이름으로 변경
vpc_name = "goorm-popcorn-vpc-dev-yourname-v2"
```

### **3. 변수 누락 오류**
```bash
# terraform.tfvars.example과 비교
diff terraform.tfvars.example terraform.tfvars

# 누락된 변수 추가
```

## 📋 **체크리스트**

### **작업 시작 전**
- [ ] 최신 코드 pull 완료
- [ ] terraform.tfvars 업데이트 확인
- [ ] 팀에 작업 시작 공지
- [ ] AWS 인증 정보 확인

### **작업 완료 후**
- [ ] terraform plan으로 변경사항 확인
- [ ] 불필요한 리소스 정리
- [ ] 팀에 작업 완료 공지
- [ ] 문서 업데이트 (필요시)

### **커밋 전**
- [ ] .tfvars 파일이 포함되지 않았는지 확인
- [ ] 민감 정보가 포함되지 않았는지 확인
- [ ] terraform.tfvars.example 업데이트 (새 변수 추가 시)

## 🚀 **고급 팁**

### **1. 별칭 설정**
```bash
# ~/.bashrc 또는 ~/.zshrc에 추가
alias tf='terraform'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfs='terraform show'
```

### **2. 자동 완성**
```bash
# Terraform 자동 완성 설정
terraform -install-autocomplete
```

### **3. 사전 검증**
```bash
# 문법 검사
terraform validate

# 포맷팅
terraform fmt

# 보안 검사 (tfsec 설치 필요)
tfsec .
```

## 📞 **도움 요청**

### **문제 발생 시**
1. **Slack #terraform 채널**에 질문
2. **GitHub Issues**에 버그 리포트
3. **팀 미팅**에서 논의

### **긴급 상황**
- 운영 환경 문제: 즉시 팀 리더에게 연락
- 보안 이슈: 즉시 보안팀에 연락
- 데이터 손실: 즉시 백업 복구 절차 실행