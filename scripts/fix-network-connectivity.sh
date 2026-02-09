#!/bin/bash

# Terraform Destroy Network Connectivity Fix Script
# 네트워크 연결 문제로 인한 terraform destroy 실패 해결

set -e

echo "🔧 Terraform Destroy Network Connectivity Fix Script"
echo "=================================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 네트워크 연결 확인
check_network_connectivity() {
    log_info "네트워크 연결 상태 확인 중..."
    
    # DNS 해상도 확인
    if ! nslookup ec2.ap-northeast-2.amazonaws.com > /dev/null 2>&1; then
        log_error "DNS 해상도 실패: ec2.ap-northeast-2.amazonaws.com"
        return 1
    fi
    
    # AWS API 연결 확인
    if ! curl -s --connect-timeout 10 https://ec2.ap-northeast-2.amazonaws.com > /dev/null; then
        log_error "AWS API 연결 실패"
        return 1
    fi
    
    log_info "네트워크 연결 정상"
    return 0
}

# DNS 캐시 플러시
flush_dns_cache() {
    log_info "DNS 캐시 플러시 중..."
    
    case "$(uname -s)" in
        Darwin)
            sudo dscacheutil -flushcache
            sudo killall -HUP mDNSResponder
            ;;
        Linux)
            if command -v systemd-resolve &> /dev/null; then
                sudo systemd-resolve --flush-caches
            elif [ -f /etc/init.d/nscd ]; then
                sudo /etc/init.d/nscd restart
            fi
            ;;
    esac
    
    log_info "DNS 캐시 플러시 완료"
}

# AWS CLI 연결 테스트
test_aws_cli() {
    log_info "AWS CLI 연결 테스트 중..."
    
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        log_error "AWS CLI 인증 실패"
        log_info "다음 명령어로 AWS 자격 증명을 확인하세요:"
        log_info "aws configure list"
        return 1
    fi
    
    log_info "AWS CLI 연결 정상"
    return 0
}

# 네트워크 인터페이스 재시작 (Linux/macOS)
restart_network_interface() {
    log_warn "네트워크 인터페이스 재시작 시도..."
    
    case "$(uname -s)" in
        Darwin)
            # macOS - Wi-Fi 재시작
            networksetup -setairportpower en0 off
            sleep 2
            networksetup -setairportpower en0 on
            sleep 5
            ;;
        Linux)
            # Linux - 네트워크 매니저 재시작
            if command -v systemctl &> /dev/null; then
                sudo systemctl restart NetworkManager
                sleep 5
            fi
            ;;
    esac
}

# VPC 엔드포인트 강제 삭제
force_delete_vpc_endpoints() {
    log_info "VPC 엔드포인트 강제 삭제 시도..."
    
    # 실패한 VPC 엔드포인트 ID들
    local endpoints=(
        "vpce-01b6c460a558e409d"
        "vpce-0807e7a065f3717a9"
        "vpce-0872a224c007e9318"
        "vpce-04d8c4d9db78a92ff"
        "vpce-07535b9c3ef832c76"
    )
    
    for endpoint in "${endpoints[@]}"; do
        log_info "VPC 엔드포인트 삭제 시도: $endpoint"
        
        # 연결 해제 시도
        aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$endpoint" --region ap-northeast-2 2>/dev/null | \
        jq -r '.VpcEndpoints[0].RouteTableIds[]?' 2>/dev/null | \
        while read -r route_table; do
            if [ -n "$route_table" ] && [ "$route_table" != "null" ]; then
                log_info "라우트 테이블에서 연결 해제: $route_table"
                aws ec2 disassociate-route-table --association-id "$route_table" --region ap-northeast-2 2>/dev/null || true
            fi
        done
        
        # 강제 삭제
        aws ec2 delete-vpc-endpoint --vpc-endpoint-id "$endpoint" --region ap-northeast-2 2>/dev/null || true
        
        # 삭제 대기
        log_info "VPC 엔드포인트 삭제 대기: $endpoint"
        aws ec2 wait vpc-endpoint-deleted --vpc-endpoint-ids "$endpoint" --region ap-northeast-2 2>/dev/null || true
    done
}

# 서브넷 종속성 해결
resolve_subnet_dependencies() {
    log_info "서브넷 종속성 해결 중..."
    
    local subnet_id="subnet-028209f9d32868072"
    
    # 서브넷에 연결된 네트워크 인터페이스 확인 및 삭제
    log_info "서브넷의 네트워크 인터페이스 확인: $subnet_id"
    
    aws ec2 describe-network-interfaces \
        --filters "Name=subnet-id,Values=$subnet_id" \
        --region ap-northeast-2 \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text 2>/dev/null | \
    while read -r eni_id; do
        if [ -n "$eni_id" ] && [ "$eni_id" != "None" ]; then
            log_info "네트워크 인터페이스 삭제: $eni_id"
            
            # 연결 해제
            aws ec2 describe-network-interfaces \
                --network-interface-ids "$eni_id" \
                --region ap-northeast-2 \
                --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
                --output text 2>/dev/null | \
            while read -r attachment_id; do
                if [ -n "$attachment_id" ] && [ "$attachment_id" != "None" ]; then
                    aws ec2 detach-network-interface --attachment-id "$attachment_id" --region ap-northeast-2 --force 2>/dev/null || true
                fi
            done
            
            # 삭제
            aws ec2 delete-network-interface --network-interface-id "$eni_id" --region ap-northeast-2 2>/dev/null || true
        fi
    done
    
    # 서브넷의 인스턴스 확인 및 종료
    log_info "서브넷의 EC2 인스턴스 확인: $subnet_id"
    
    aws ec2 describe-instances \
        --filters "Name=subnet-id,Values=$subnet_id" "Name=instance-state-name,Values=running,stopped,stopping" \
        --region ap-northeast-2 \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text 2>/dev/null | \
    while read -r instance_id; do
        if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
            log_info "EC2 인스턴스 종료: $instance_id"
            aws ec2 terminate-instances --instance-ids "$instance_id" --region ap-northeast-2 2>/dev/null || true
            
            # 종료 대기
            log_info "인스턴스 종료 대기: $instance_id"
            aws ec2 wait instance-terminated --instance-ids "$instance_id" --region ap-northeast-2 2>/dev/null || true
        fi
    done
}

# 인터넷 게이트웨이 연결 해제
detach_internet_gateway() {
    log_info "인터넷 게이트웨이 연결 해제 중..."
    
    local igw_id="igw-0514d15e9ebf255aa"
    local vpc_id="vpc-0deb08e9c6fb58fb0"
    
    # 퍼블릭 IP 주소 해제
    log_info "VPC의 퍼블릭 IP 주소 해제: $vpc_id"
    
    aws ec2 describe-addresses \
        --region ap-northeast-2 \
        --query 'Addresses[?Domain==`vpc`].AllocationId' \
        --output text 2>/dev/null | \
    while read -r allocation_id; do
        if [ -n "$allocation_id" ] && [ "$allocation_id" != "None" ]; then
            log_info "Elastic IP 해제: $allocation_id"
            aws ec2 release-address --allocation-id "$allocation_id" --region ap-northeast-2 2>/dev/null || true
        fi
    done
    
    # NAT 게이트웨이 삭제
    log_info "NAT 게이트웨이 확인 및 삭제"
    
    aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$vpc_id" \
        --region ap-northeast-2 \
        --query 'NatGateways[?State!=`deleted`].NatGatewayId' \
        --output text 2>/dev/null | \
    while read -r nat_id; do
        if [ -n "$nat_id" ] && [ "$nat_id" != "None" ]; then
            log_info "NAT 게이트웨이 삭제: $nat_id"
            aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --region ap-northeast-2 2>/dev/null || true
            
            # 삭제 대기
            log_info "NAT 게이트웨이 삭제 대기: $nat_id"
            aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$nat_id" --region ap-northeast-2 2>/dev/null || true
        fi
    done
    
    # 인터넷 게이트웨이 연결 해제
    log_info "인터넷 게이트웨이 연결 해제: $igw_id from $vpc_id"
    aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" --region ap-northeast-2 2>/dev/null || true
    
    # 잠시 대기
    sleep 10
}

# 메인 실행 함수
main() {
    log_info "네트워크 연결 문제 해결 시작..."
    
    # 1. 네트워크 연결 확인
    if ! check_network_connectivity; then
        log_warn "네트워크 연결 문제 감지. 복구 시도..."
        
        # DNS 캐시 플러시
        flush_dns_cache
        
        # 네트워크 인터페이스 재시작
        restart_network_interface
        
        # 다시 확인
        sleep 10
        if ! check_network_connectivity; then
            log_error "네트워크 연결 복구 실패. 수동으로 네트워크 설정을 확인하세요."
            exit 1
        fi
    fi
    
    # 2. AWS CLI 테스트
    if ! test_aws_cli; then
        log_error "AWS CLI 설정을 확인하세요."
        exit 1
    fi
    
    # 3. AWS 리소스 정리
    log_info "AWS 리소스 정리 시작..."
    
    # VPC 엔드포인트 강제 삭제
    force_delete_vpc_endpoints
    
    # 서브넷 종속성 해결
    resolve_subnet_dependencies
    
    # 인터넷 게이트웨이 연결 해제
    detach_internet_gateway
    
    log_info "네트워크 연결 문제 해결 완료!"
    log_info "이제 terraform destroy를 다시 실행해보세요."
}

# 스크립트 실행
main "$@"