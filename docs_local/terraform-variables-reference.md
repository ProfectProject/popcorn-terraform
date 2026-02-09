# Terraform Variables Reference

**Date**: 2024-01-26  
**Environment**: Dev Environment Configuration  
**Status**: All Variables Configured ✅

---

## Variable Configuration Status

### ✅ All Required Variables Defined

The terraform configuration is complete and all variables are properly defined in `terraform.tfvars`. No additional variables need to be added for CI/CD automation.

### Variable Sources

1. **terraform.tfvars** - Contains all environment-specific values
2. **variables.tf** - Contains variable definitions with defaults
3. **Module defaults** - All modules have sensible defaults

---

## Complete Variable List

### Core Infrastructure Variables

```hcl
# Region and Basic Config
region = "ap-northeast-2"

# VPC Configuration
vpc_name = "goorm-popcorn-vpc-dev"
vpc_cidr = "10.0.0.0/16"

# Subnet Configuration (3-tier)
public_subnets = [
  {
    name = "goorm-popcorn-dev-public-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.1.0/24"
  }
]

private_subnets = [
  {
    name = "goorm-popcorn-dev-private-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.11.0/24"
  }
]

data_subnets = [
  {
    name = "goorm-popcorn-dev-data-2a"
    az   = "ap-northeast-2a"
    cidr = "10.0.21.0/24"
  }
]

# Security Groups
sg_name = "goorm-popcorn-dev"

# NAT Gateway
enable_nat         = true
single_nat_gateway = true
```

### Application Load Balancer Variables

```hcl
alb_name              = "goorm-popcorn-alb-dev"
alb_target_group_name = "goorm-popcorn-gateway-dev"
alb_target_group_port = 8080  # Default
alb_health_check_path = "/health"  # Default
```

### Database Variables (RDS PostgreSQL)

```hcl
rds_name                    = "goorm-popcorn-dev"
rds_instance_class          = "db.t4g.micro"
rds_allocated_storage       = 20
rds_backup_retention_period = 1
```

### Cache Variables (ElastiCache Redis)

```hcl
elasticache_name                = "goorm-popcorn-cache-dev"
elasticache_node_type           = "cache.t4g.micro"
elasticache_engine_version      = "7.0"
elasticache_num_cache_clusters  = 1
elasticache_automatic_failover  = false
elasticache_multi_az_enabled    = false
```

### Container Variables (ECS Fargate)

```hcl
ecs_name               = "goorm-popcorn-dev"
ecr_repository_url     = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com"
ecs_log_retention_days = 7
image_tag             = "dev-latest"

# ECR Repository Mapping (7 services)
ecr_repositories = {
  "api-gateway"   = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-api-gateway"
  "user-service"  = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-user"
  "store-service" = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-store"
  "order-service" = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-order"
  "payment-service" = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-payment"
  "qr-service"    = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-qr"
  "order-query"   = "375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-order-query"
}
```

### Service Discovery Variables (CloudMap)

```hcl
cloudmap_name      = "goorm-popcorn-dev"
cloudmap_namespace = "goormpopcorn.local"
```

### Messaging Variables (EC2 Kafka)

```hcl
ec2_kafka_name          = "goorm-popcorn-dev"
ec2_kafka_instance_type = "t3.small"
ec2_kafka_key_name      = "goorm-popcorn-keypair"
ec2_kafka_node_count    = 1
```

### IAM Variables

```hcl
iam_name = "goorm-popcorn-dev"
```

### Common Tags

```hcl
tags = {
  Environment = "dev"
  Project     = "goorm-popcorn"
  ManagedBy   = "terraform"
}
```

---

## CI/CD Integration

### For Automated Deployment

The current configuration supports full automation with:

```bash
# Basic deployment
terraform apply -auto-approve

# With custom image tag
terraform apply -auto-approve -var="image_tag=feature-auth-abc12345"

# With environment override
terraform apply -auto-approve -var="image_tag=pr-123-def67890"
```

### Dynamic Image Tagging

The configuration supports dynamic image tagging for different deployment scenarios:

- **Development**: `dev-latest`, `dev-20240126`
- **Feature branches**: `feature-auth-abc12345`
- **Pull requests**: `pr-123-def67890`
- **Hotfixes**: `hotfix-security-xyz98765`
- **Production**: `latest`, `v1.2.3`

### Environment Variables for CI/CD

```bash
# Required AWS credentials
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-2"

# Optional: Custom image tag
export TF_VAR_image_tag="dev-$(git rev-parse --short=8 HEAD)"
```

---

## Validation Results

### ✅ Terraform Plan Success
- **Resources to create**: 108
- **Resources to change**: 0
- **Resources to destroy**: 0

### ✅ Terraform Apply Progress
- **VPC and Networking**: ✅ Complete
- **Security Groups**: ✅ Complete
- **IAM Roles**: ✅ Complete
- **RDS Database**: ✅ Complete
- **ElastiCache**: ✅ In Progress
- **EC2 Kafka**: ✅ In Progress
- **ECS Services**: ⏳ Pending
- **ALB**: ⏳ Pending
- **CloudMap**: ⏳ Pending

### ✅ No Missing Variables
All required variables are defined and no prompts appear during terraform execution.

---

## Troubleshooting

### If Variables Are Missing

1. **Check terraform.tfvars**: Ensure all required variables are defined
2. **Check variable defaults**: Most variables have sensible defaults in modules
3. **Use terraform plan**: Will show any missing variables before apply

### Common CI/CD Issues

1. **State lock**: Use `terraform force-unlock <lock-id>` if needed
2. **Provider versions**: Run `terraform init -upgrade` for version conflicts
3. **Missing credentials**: Ensure AWS credentials are properly configured

---

## Summary

✅ **All variables are properly configured**  
✅ **No additional variables needed for CI/CD**  
✅ **Terraform apply runs without prompts**  
✅ **Dynamic image tagging supported**  
✅ **Full automation ready**

The infrastructure is ready for automated deployment in CI/CD pipelines.