# 환경별 구성 비교

## 📊 환경별 리소스 비교

| 구성 요소 | Dev | Staging | Production |
|-----------|-----|---------|------------|
| **목적** | 개발/테스트 | QA/통합테스트 | 실제 서비스 |
| **가용성** | 단일 AZ | Multi-AZ | Multi-AZ |
| **비용 우선순위** | 최소 비용 | 중간 | 안정성 우선 |

## 🌐 네트워크 구성

| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **VPC CIDR** | 10.1.0.0/16 | 10.0.0.0/16 | 10.0.0.0/16 |
| **Availability Zones** | 1개 (2a) | 2개 (2a, 2c) | 2개 (2a, 2c) |
| **Public Subnets** | 1개 | 2개 | 2개 |
| **Private App Subnets** | 1개 | 2개 | 2개 |
| **Private Data Subnets** | 1개 | 2개 | 2개 |
| **NAT Gateway** | 1개 | 2개 | 2개 |
| **VPC Endpoints** | ❌ 비활성화 | ✅ 활성화 | ✅ 활성화 |

## 💻 ECS Fargate 구성

### API Gateway
| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **CPU** | 256 | 256 | 256 |
| **Memory** | 512MB | 512MB | 512MB |
| **Desired Count** | 1 | 1 | 2 |
| **Min/Max** | 1-2 | 1-3 | 2-4 |

### 마이크로서비스 (User, Store, Order, QR)
| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **CPU** | 256 | 512 | 512 |
| **Memory** | 512MB | 1024MB | 1024MB |
| **Desired Count** | 1 | 1 | 2 |
| **Min/Max** | 1-2 | 1-8 | 2-20 |

### Payment Service (중요도 높음)
| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **CPU** | 256 | 512 | 512 |
| **Memory** | 512MB | 1024MB | 1024MB |
| **Desired Count** | 1 | 2 | 3 |
| **Min/Max** | 1-2 | 2-10 | 3-30 |

## 🗄️ 데이터베이스 구성

### Aurora PostgreSQL
| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **Instance Class** | db.t4g.medium | db.r6g.large | db.r6g.large |
| **Instance Count** | 1 (Writer만) | 2 (Writer+Reader) | 3 (Writer+2Reader) |
| **Auto Scaling** | ❌ 비활성화 | ✅ 2-5개 | ✅ 2-10개 |
| **Backup Retention** | 1일 | 7일 | 30일 |
| **Performance Insights** | ❌ 비활성화 | ✅ 활성화 | ✅ 활성화 |
| **Enhanced Monitoring** | ❌ 비활성화 | ✅ 60초 | ✅ 60초 |

### ElastiCache Redis
| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **Node Type** | cache.t4g.micro | cache.t4g.micro | cache.t4g.small |
| **Node Count** | 1 (단일) | 2 (Primary+Replica) | 2 (Primary+Replica) |
| **Multi-AZ** | ❌ 비활성화 | ✅ 활성화 | ✅ 활성화 |
| **Auto Failover** | ❌ 비활성화 | ✅ 활성화 | ✅ 활성화 |
| **Snapshot Retention** | 1일 | 7일 | 30일 |

## 📨 MSK Serverless
| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **Cluster** | ✅ 동일 | ✅ 동일 | ✅ 동일 |
| **Monitoring** | ❌ 비활성화 | ✅ 활성화 | ✅ 활성화 |
| **Log Retention** | 3일 | 7일 | 30일 |

## 📊 모니터링 및 로깅

| 항목 | Dev | Staging | Production |
|------|-----|---------|------------|
| **CloudWatch Logs Retention** | 3일 | 7일 | 30일 |
| **Container Insights** | ✅ 활성화 | ✅ 활성화 | ✅ 활성화 |
| **Enhanced Monitoring** | ❌ 비활성화 | ✅ 활성화 | ✅ 활성화 |
| **Performance Insights** | ❌ 비활성화 | ✅ 활성화 | ✅ 활성화 |
| **CloudWatch Alarms** | 기본만 | 전체 | 전체 + PagerDuty |

## 💰 예상 월간 비용

| 환경 | 예상 비용 | 주요 절감 요소 |
|------|-----------|----------------|
| **Dev** | **~$150/월** | • 단일 AZ<br>• 최소 인스턴스<br>• Auto Scaling 비활성화<br>• VPC Endpoints 비활성화<br>• 모니터링 최소화 |
| **Staging** | **~$400/월** | • Multi-AZ<br>• 중간 사양<br>• 제한적 Auto Scaling<br>• VPC Endpoints 활성화 |
| **Production** | **~$765/월** | • Multi-AZ<br>• 고사양<br>• 완전 Auto Scaling<br>• 모든 기능 활성화<br>• 백업 30일 |

## 🔧 환경별 설정 파일

### Dev 환경 수정 포인트
```bash
# terraform/environments/dev/terraform.tfvars
vpc_cidr = "10.1.0.0/16"                    # 별도 CIDR
enable_vpc_endpoints = false                # 비용 절감
aurora_instance_class = "db.t4g.medium"     # 작은 인스턴스
aurora_instance_count = 1                   # Writer만
elasticache_node_type = "cache.t4g.micro"   # 최소 사양
```

### Staging 환경 수정 포인트
```bash
# terraform/environments/staging/terraform.tfvars
aurora_instance_count = 2                   # Writer + Reader 1개
elasticache_node_type = "cache.t4g.micro"   # 작은 인스턴스
```

### Production 환경 수정 포인트
```bash
# terraform/environments/prod/terraform.tfvars
aurora_instance_count = 3                   # Writer + Reader 2개
elasticache_node_type = "cache.t4g.small"   # 더 큰 인스턴스
```

## 🚀 배포 순서

### 1. Dev 환경 (개발자 개인/팀 테스트)
```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# 값 수정 후
terraform apply
```

### 2. Staging 환경 (QA/통합 테스트)
```bash
cd terraform/environments/staging
cp terraform.tfvars.example terraform.tfvars
# 값 수정 후
terraform apply
```

### 3. Production 환경 (실제 서비스)
```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# 값 수정 후
terraform apply
```

## 🎯 환경별 사용 목적

### Dev 환경
- **목적**: 개발자 개인 테스트, 기능 개발
- **특징**: 최소 비용, 빠른 배포, 불안정해도 OK
- **사용자**: 개발팀
- **데이터**: 테스트 데이터

### Staging 환경
- **목적**: QA 테스트, 통합 테스트, 성능 테스트
- **특징**: Production과 유사하지만 비용 절감
- **사용자**: QA팀, 개발팀
- **데이터**: Production 유사 테스트 데이터

### Production 환경
- **목적**: 실제 서비스 운영
- **특징**: 최고 안정성, 성능, 모니터링
- **사용자**: 실제 고객
- **데이터**: 실제 운영 데이터

## ⚠️ 주의사항

1. **Dev 환경 제약사항**:
   - 단일 AZ로 인한 가용성 제한
   - Auto Scaling 비활성화로 부하 테스트 제한
   - VPC Endpoints 비활성화로 NAT Gateway 비용 발생

2. **환경간 데이터 격리**:
   - 각 환경은 완전히 독립된 VPC 사용
   - 데이터베이스, 캐시 모두 분리
   - 실수로 Production 데이터 접근 불가

3. **비용 관리**:
   - Dev 환경은 업무 시간에만 운영 고려
   - Staging은 QA 기간에만 확장
   - Production은 24/7 운영

이렇게 환경별로 차별화된 구성을 통해 개발 단계별 요구사항을 충족하면서도 비용을 최적화할 수 있습니다.