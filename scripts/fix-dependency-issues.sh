#!/bin/bash

# 의존성 문제 해결 스크립트
# Internet Gateway와 Subnet 의존성 문제 해결

set -e

REGION="ap-northeast-2"
VPC_ID="vpc-0deb08e9c6fb58fb0"
SUBNET_ID="subnet-028209f9d32868072"
IGW_ID="igw-0514d15e9ebf255aa"

echo "🔧 Fixing dependency issues for VPC: $VPC_ID"

# 1. 해당 Subnet에 연결된 모든 리소스 확인 및 정리
echo "1. Checking resources in subnet: $SUBNET_ID"

# Network Interfaces 확인 및 정리
echo "  - Checking Network Interfaces..."
aws ec2 describe-network-interfaces --region $REGION --filters "Name=subnet-id,Values=$SUBNET_ID" --query 'NetworkInterfaces[].[NetworkInterfaceId,Status,Description,Attachment.InstanceId]' --output table

aws ec2 describe-network-interfaces --region $REGION --filters "Name=subnet-id,Values=$SUBNET_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text | while read eni_id; do
    if [ ! -z "$eni_id" ] && [ "$eni_id" != "None" ]; then
        echo "    Processing ENI: $eni_id"
        
        # ENI 상세 정보 확인
        ENI_INFO=$(aws ec2 describe-network-interfaces --region $REGION --network-interface-ids $eni_id --query 'NetworkInterfaces[0]' --output json)
        
        # 연결된 인스턴스가 있다면 분리
        ATTACHMENT_ID=$(echo $ENI_INFO | jq -r '.Attachment.AttachmentId // empty')
        if [ ! -z "$ATTACHMENT_ID" ]; then
            echo "      Detaching from attachment: $ATTACHMENT_ID"
            aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --region $REGION --force || true
            sleep 10
        fi
        
        # ENI 삭제
        echo "      Deleting ENI: $eni_id"
        aws ec2 delete-network-interface --network-interface-id $eni_id --region $REGION || true
    fi
done

# 2. Elastic IP 확인 및 해제
echo "2. Checking and releasing Elastic IPs..."
aws ec2 describe-addresses --region $REGION --filters "Name=domain,Values=vpc" --query 'Addresses[].[AllocationId,PublicIp,AssociationId,NetworkInterfaceId]' --output table

aws ec2 describe-addresses --region $REGION --filters "Name=domain,Values=vpc" --query 'Addresses[].AllocationId' --output text | while read alloc_id; do
    if [ ! -z "$alloc_id" ] && [ "$alloc_id" != "None" ]; then
        echo "  - Releasing Elastic IP: $alloc_id"
        aws ec2 release-address --allocation-id $alloc_id --region $REGION || true
    fi
done

# 3. NAT Gateway 확인 및 삭제
echo "3. Checking and deleting NAT Gateways..."
aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[].[NatGatewayId,State,SubnetId]' --output table

aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --filter "Name=state,Values=available,pending,deleting" --query 'NatGateways[].NatGatewayId' --output text | while read nat_id; do
    if [ ! -z "$nat_id" ] && [ "$nat_id" != "None" ]; then
        echo "  - Deleting NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id $nat_id --region $REGION || true
    fi
done

# 4. Load Balancer 확인 및 삭제
echo "4. Checking Load Balancers in VPC..."
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].[LoadBalancerArn,LoadBalancerName,State.Code]" --output table

aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text | while read lb_arn; do
    if [ ! -z "$lb_arn" ] && [ "$lb_arn" != "None" ]; then
        echo "  - Deleting Load Balancer: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn $lb_arn --region $REGION || true
    fi
done

# 5. VPC Endpoints 확인 및 삭제
echo "5. Checking VPC Endpoints..."
aws ec2 describe-vpc-endpoints --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].[VpcEndpointId,State,ServiceName]' --output table

aws ec2 describe-vpc-endpoints --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].VpcEndpointId' --output text | while read endpoint_id; do
    if [ ! -z "$endpoint_id" ] && [ "$endpoint_id" != "None" ]; then
        echo "  - Deleting VPC Endpoint: $endpoint_id"
        aws ec2 delete-vpc-endpoint --vpc-endpoint-id $endpoint_id --region $REGION || true
    fi
done

# 6. 잠시 대기 (리소스 정리 시간)
echo "6. Waiting for resources to be cleaned up..."
sleep 60

# 7. Internet Gateway 분리 재시도
echo "7. Attempting to detach Internet Gateway..."
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION || echo "  - IGW detach failed, will try again later"

# 8. Subnet 삭제 재시도
echo "8. Attempting to delete Subnet..."
aws ec2 delete-subnet --subnet-id $SUBNET_ID --region $REGION || echo "  - Subnet delete failed, will try again later"

echo ""
echo "✅ Dependency cleanup completed!"
echo "⚠️  Wait 2-3 minutes, then run terraform destroy again."
echo ""
echo "If issues persist, check remaining resources:"
echo "  aws ec2 describe-network-interfaces --region $REGION --filters Name=subnet-id,Values=$SUBNET_ID"
echo "  aws ec2 describe-addresses --region $REGION --filters Name=domain,Values=vpc"