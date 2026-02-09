# 태스크 1.3: ALB 변수 정의

## 완료 일시
2025-02-08

## 태스크 내용
- name, vpc_id, subnet_ids, security_group_ids 변수
- internal, certificate_arn 변수
- target_groups, listener_rules 변수
- Requirements: 6.3, 6.4

## 실행 결과

### ✅ 검증 완료

기존 `modules/alb/variables.tf` 파일을 검증한 결과, **설계 문서에 정의된 모든 필수 변수가 완벽하게 구현**되어 있습니다.

### 📝 구현된 변수 목록

#### 필수 변수 (Requirements 6.3, 6.4)

1. **name** (string)
   - ALB 이름

2. **vpc_id** (string)
   - VPC ID

3. **subnet_ids** (list(string))
   - ALB를 배치할 서브넷 ID 목록 (Public Subnet)

4. **security_group_ids** (list(string))
   - ALB에 연결할 보안 그룹 ID 목록

5. **internal** (bool, default: false)
   - 내부 ALB 여부 (true: 내부, false: 외부)

6. **certificate_arn** (string)
   - ACM 인증서 ARN (HTTPS 리스너용)

7. **target_groups** (list(object), default: [])
   - 타겟 그룹 설정 목록 (Host-based 라우팅용)
   - 각 타겟 그룹은 name, port, protocol, health_check 포함

8. **listener_rules** (list(object), default: [])
   - 리스너 규칙 설정 목록 (Host-based 라우팅)
   - 각 규칙은 priority, host_header, target_group_index 포함

#### 추가 구현된 변수

9. **target_group_name** (string, default: null)
   - 기본 타겟 그룹 이름

10. **target_group_port** (number, default: 8080)
    - 기본 타겟 그룹 포트

11. **health_check_path** (string, default: "/actuator/health")
    - 기본 헬스체크 경로

12. **tags** (map(string), default: {})
    - 리소스에 적용할 태그 (Requirements 13.6 충족)

13. **enable_access_logs** (bool, default: false)
    - ALB 액세스 로그 활성화 여부

14. **access_logs_bucket** (string, default: null)
    - ALB 액세스 로그를 저장할 S3 버킷

15. **access_logs_prefix** (string, default: "alb")
    - ALB 액세스 로그 S3 prefix

16. **enable_cloudwatch_alarms** (bool, default: true)
    - CloudWatch 알람 활성화 여부 (Requirements 10.5, 10.6 충족)

17. **sns_topic_arn** (string, default: null)
    - CloudWatch 알람용 SNS 토픽 ARN

### 🎯 요구사항 충족

- ✅ Requirements 6.3: ALB를 Public Subnet에 배치
- ✅ Requirements 6.4: Management ALB를 Public Subnet에 배치
- ✅ Requirements 13.6: 리소스 태그 관리
- ✅ Requirements 10.5: CloudWatch 알람 구성
- ✅ Requirements 10.6: SNS 알림 전송

### 📊 main.tf 연동 확인

- ✅ target_groups 변수가 aws_lb_target_group.additional 리소스에서 올바르게 사용됨
- ✅ listener_rules 변수가 aws_lb_listener_rule.host_based 리소스에서 올바르게 사용됨
- ✅ Host-based 라우팅, HTTPS 리스너, HTTP→HTTPS 리다이렉트 모두 구현됨

### 결론

태스크 1.3은 이미 완료되어 있으며, 추가 작업이 필요하지 않습니다. 현재 구현은 설계 문서의 요구사항을 모두 충족하고 있습니다.

## 검증된 파일

```
modules/alb/
└── variables.tf (검증 완료)
```

## 다음 단계

태스크 1.4: ALB 출력 값 정의
