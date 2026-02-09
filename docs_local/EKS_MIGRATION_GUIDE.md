# EKS Migration Guide

## 📋 개요

이 문서는 Popcorn MSA 시스템을 ECS Fargate에서 Amazon EKS로 마이그레이션하는 가이드입니다.

**마이그레이션 타임라인**: 6-12개월 후 (요구사항 문서 기준)

## 🎯 마이그레이션 목표

### 현재 상태 (ECS Fargate)
- 8개 마이크로서비스 (API Gateway + 7개 서비스)
- ECS Fargate 기반 컨테이너 오케스트레이션
- Application Load Balancer 기반 라우팅
- AWS Cloud Map 서비스 디스커버리

### 목표 상태 (EKS)
- 동일한 8개 마이크로서비스
- Kubernetes 네이티브 오케스트레이션
- Ingress Controller 기반 라우팅
- Kubernetes Service Discovery
- 표준 Kubernetes API 활용
- 풍부한 생태계 (Helm, Operators)
- 멀티 클라우드 이식성

## 🚀 EKS 모듈 활성화

### 1단계: EKS 클러스터 생성

```bash
# dev 환경에서 EKS 활성화
cd envs/dev

# terraform.tfvars에 추가
echo 'enable_eks = true' >> terraform.tfvars

# EKS 클러스터 생성
terraform plan -target=module.eks
terraform apply -target=module.eks
```

### 2단계: kubectl 설정

```bash
# EKS 클러스터 접근 설정
aws eks update-kubeconfig --region ap-northeast-2 --name goorm-popcorn-dev-eks

# 클러스터 상태 확인
kubectl get nodes
kubectl get pods --all-namespaces
```

### 3단계: 네임스페이스 생성

```bash
# 애플리케이션 네임스페이스 생성
kubectl create namespace popcorn-app
kubectl create namespace popcorn-monitoring
kubectl create namespace popcorn-logging
```

## 📦 컨테이너 이미지 준비

### ECR 이미지 태깅 전략

```bash
# 현재 ECS 이미지를 EKS용으로 태깅
aws ecr describe-repositories --query 'repositories[].repositoryName' --output text | while read repo; do
    # 최신 이미지 가져오기
    LATEST_TAG=$(aws ecr describe-images --repository-name $repo --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)
    
    # EKS용 태그 추가
    docker pull 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/$repo:$LATEST_TAG
    docker tag 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/$repo:$LATEST_TAG \
               375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/$repo:eks-latest
    docker push 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/$repo:eks-latest
done
```

## 🔧 Kubernetes 매니페스트 생성

### API Gateway 배포

```yaml
# k8s/api-gateway.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: popcorn-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: 375896310755.dkr.ecr.ap-northeast-2.amazonaws.com/goorm-popcorn-api-gateway:eks-latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "dev"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: api-gateway
  namespace: popcorn-app
spec:
  selector:
    app: api-gateway
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

### Ingress 설정

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: popcorn-ingress
  namespace: popcorn-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
spec:
  rules:
  - host: dev.goormpopcorn.shop
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 8080
```

## 📊 모니터링 설정

### Prometheus + Grafana 설치

```bash
# Prometheus Operator 설치
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace popcorn-monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=7d
```

### Jaeger 분산 추적

```bash
# Jaeger Operator 설치
kubectl create namespace observability
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml -n observability

# Jaeger 인스턴스 생성
kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: popcorn-monitoring
spec:
  strategy: production
  storage:
    type: elasticsearch
EOF
```

## 🔄 마이그레이션 전략

### Phase 1: 준비 (1-2개월)
- [x] EKS 클러스터 구축
- [x] 모니터링 스택 설치
- [ ] Kubernetes 매니페스트 작성
- [ ] CI/CD 파이프라인 수정
- [ ] 성능 테스트 환경 구축

### Phase 2: 하이브리드 운영 (2-3개월)
- [ ] 트래픽 분할 (ECS 80% / EKS 20%)
- [ ] 점진적 트래픽 이동
- [ ] 성능 및 안정성 모니터링
- [ ] 이슈 해결 및 최적화

### Phase 3: 완전 전환 (1-2개월)
- [ ] 모든 트래픽을 EKS로 이동
- [ ] ECS 리소스 정리
- [ ] 문서화 및 운영 가이드 작성
- [ ] 팀 교육 및 지식 전수

## 🎛️ Auto Scaling 설정

### Horizontal Pod Autoscaler (HPA)

```yaml
# k8s/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
  namespace: popcorn-app
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

### Vertical Pod Autoscaler (VPA)

```yaml
# k8s/vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-gateway-vpa
  namespace: popcorn-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: api-gateway
      maxAllowed:
        cpu: 1
        memory: 1Gi
      minAllowed:
        cpu: 100m
        memory: 128Mi
```

## 🔐 보안 설정

### Pod Security Standards

```yaml
# k8s/pod-security.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: popcorn-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Network Policies

```yaml
# k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: popcorn-network-policy
  namespace: popcorn-app
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    - podSelector: {}
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
  - to:
    - podSelector: {}
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

## 📈 성능 최적화

### 리소스 요청 및 제한

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### 노드 어피니티

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/arch
          operator: In
          values:
          - amd64
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
          - t3.medium
          - t3.large
```

## 🚨 트러블슈팅

### 일반적인 문제들

1. **Pod가 Pending 상태**
   ```bash
   kubectl describe pod <pod-name> -n popcorn-app
   # 리소스 부족 또는 노드 어피니티 문제 확인
   ```

2. **Service 연결 실패**
   ```bash
   kubectl get endpoints -n popcorn-app
   # 엔드포인트가 올바르게 생성되었는지 확인
   ```

3. **Ingress 접근 불가**
   ```bash
   kubectl describe ingress popcorn-ingress -n popcorn-app
   # ALB 생성 상태 및 설정 확인
   ```

## 📚 추가 리소스

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Charts](https://helm.sh/)
- [CNCF Landscape](https://landscape.cncf.io/)

## 🎯 성공 기준

- [ ] 모든 서비스가 EKS에서 정상 동작
- [ ] 응답 시간 P95 < 500ms 유지
- [ ] 가용성 99.9% 이상 달성
- [ ] 비용 증가 < 20%
- [ ] 팀의 Kubernetes 운영 역량 확보

---

**다음 단계**: Phase 1 준비 작업을 시작하여 EKS 클러스터를 구축하고 기본 모니터링을 설정합니다.