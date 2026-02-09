#!/bin/bash

# Popcorn MSA Infrastructure Force Cleanup Script
# 의존성 문제로 terraform destroy 실패 시 사용

set -e

REGION="ap-northeast-2"
ENV="dev"
PROJECT="goorm-popcorn"
VPC_ID="vpc-0deb08e9c6fb58fb0"
SUBNET_ID="subnet-028209f9d32868072"
IGW_ID="igw-0514d15e9ebf255aa"

echo "🚨 Force cleanup starting for ${PROJECT}-${ENV}..."
echo "VPC ID: $VPC_ID"
echo "Subnet ID: $SUBNET_ID"
echo "IGW ID: $IGW_ID"

# 1. ECS Services 및 Tasks 정리 (가장 먼저)
echo "1. Cleaning up ECS resources..."
CLUSTER_NAME="${PROJECT}-${ENV}-cluster"

# ECS Services 중지 및 삭제
echo "  - Stopping ECS services..."
aws ecs list-services --cluster $CLUSTER_NAME --region $REGION --query 'serviceArns[]' --output text 2>/dev/null | while read service; do
    if [ ! -z "$service" ] && [ "$service" != "None" ]; then
        echo "    Updating service to 0 desired count: $service"
        aws ecs update-service --cluster $CLUSTER_NAME --service $service --desired-count 0 --region $REGION 2>/dev/null || true
        sleep 10
        echo "    Deleting service: $service"
        aws ecs delete-service --cluster $CLUSTER_NAME --service $service --region $REGION 2>/dev/null || true
    fi
done

# ECS Tasks 강제 중지
echo "  - Stopping ECS tasks..."
aws ecs list-tasks --cluster $CLUSTER_NAME --region $REGION --query 'taskArns[]' --output text 2>/dev/null | while read task; do
    if [ ! -z "$task" ] && [ "$task" != "None" ]; then
        echo "    Stopping task: $task"
        aws ecs stop-task --cluster $CLUSTER_NAME --task $task --region $REGION 2>/dev/null || true
    fi
done

# 2. Network Interfaces 정리 (중요!)
echo "2. Cleaning up Network Interfaces in subnet..."
aws ec2 describe-network-interfaces --region $REGION --filters "Name=subnet-id,Values=$SUBNET_ID" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text 2>/dev/null | while read eni_id; do
    if [ ! -z "$eni_id" ] && [ "$eni_id" != "None" ]; then
        echo "  - Detaching and deleting ENI: $eni_id"
        
        # ENI가 연결되어 있다면 분리
        ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --region $REGION --network-interface-ids $eni_id --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || echo "")
        if [ "$ATTACHMENT_ID" != "" ] && [ "$ATTACHMENT_ID" != "None" ]; then
            aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --region $REGION --force 2>/dev/null || true
            sleep 5
        fi
        
        # ENI 삭제
        aws ec2 delete-network-interface --network-interface-id $eni_id --region $REGION 2>/dev/null || true
    fi
done

# 3. Elastic IP 해제 (IGW 분리를 위해 필수)
echo "3. Releasing Elastic IPs..."
aws ec2 describe-addresses --region $REGION --filters "Name=domain,Values=vpc" --query 'Addresses[].AllocationId' --output text 2>/dev/null | while read alloc_id; do
    if [ ! -z "$alloc_id" ] && [ "$alloc_id" != "None" ]; then
        echo "  - Releasing Elastic IP: $alloc_id"
        aws ec2 release-address --allocation-id $alloc_id --region $REGION 2>/dev/null || true
    fi
done

# 4. NAT Gateway 정리 (Elastic IP 사용하므로 먼저 삭제)
echo "4. Cleaning up NAT Gateways..."
aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>/dev/null | while read nat_id; do
    if [ ! -z "$nat_id" ] && [ "$nat_id" != "None" ]; then
        echo "  - Deleting NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id $nat_id --region $REGION 2>/dev/null || true
    fi
done

echo "  - Waiting for NAT Gateways to be deleted..."
sleep 30

# 5. Load Balancer 정리
echo "5. Cleaning up Load Balancers..."
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT}-${ENV}')].LoadBalancerArn" --output text 2>/dev/null | while read lb_arn; do
    if [ ! -z "$lb_arn" ] && [ "$lb_arn" != "None" ]; then
        echo "  - Deleting Load Balancer: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn $lb_arn --region $REGION 2>/dev/null || true
    fi
done

# 6. Target Groups 정리
echo "6. Cleaning up ALB Target Groups..."
aws elbv2 describe-target-groups --region $REGION --query "TargetGroups[?contains(TargetGroupName, '${PROJECT}-${ENV}')].TargetGroupArn" --output text 2>/dev/null | while read tg_arn; do
    if [ ! -z "$tg_arn" ] && [ "$tg_arn" != "None" ]; then
        echo "  - Deleting Target Group: $tg_arn"
        aws elbv2 delete-target-group --target-group-arn $tg_arn --region $REGION 2>/dev/null || true
    fi
done

# 7. VPC Endpoints 정리
echo "7. Cleaning up VPC Endpoints..."
aws ec2 describe-vpc-endpoints --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[].VpcEndpointId' --output text 2>/dev/null | while read endpoint_id; do
    if [ ! -z "$endpoint_id" ] && [ "$endpoint_id" != "None" ]; then
        echo "  - Deleting VPC Endpoint: $endpoint_id"
        aws ec2 delete-vpc-endpoint --vpc-endpoint-id $endpoint_id --region $REGION 2>/dev/null || true
    fi
done

# 8. Security Groups 정리 (기본 SG 제외)
echo "8. Cleaning up Security Groups..."
aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null | while read sg_id; do
    if [ ! -z "$sg_id" ] && [ "$sg_id" != "None" ]; then
        echo "  - Deleting Security Group: $sg_id"
        # 먼저 모든 규칙 삭제
        aws ec2 revoke-security-group-ingress --group-id $sg_id --source-group $sg_id --protocol all --region $REGION 2>/dev/null || true
        aws ec2 revoke-security-group-egress --group-id $sg_id --source-group $sg_id --protocol all --region $REGION 2>/dev/null || true
        # 그룹 삭제
        aws ec2 delete-security-group --group-id $sg_id --region $REGION 2>/dev/null || true
    fi
done

# 9. Route Tables 정리 (기본 RT 제외)
echo "9. Cleaning up Route Tables..."
aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text 2>/dev/null | while read rt_id; do
    if [ ! -z "$rt_id" ] && [ "$rt_id" != "None" ]; then
        echo "  - Deleting Route Table: $rt_id"
        aws ec2 delete-route-table --route-table-id $rt_id --region $REGION 2>/dev/null || true
    fi
done

# 10. Internet Gateway 분리 및 삭제
echo "10. Detaching and deleting Internet Gateway..."
if [ "$IGW_ID" != "" ]; then
    echo "  - Detaching Internet Gateway: $IGW_ID from VPC: $VPC_ID"
    aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION 2>/dev/null || true
    
    echo "  - Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $REGION 2>/dev/null || true
fi

# 11. Subnets 정리
echo "11. Cleaning up Subnets..."
aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text 2>/dev/null | while read subnet_id; do
    if [ ! -z "$subnet_id" ] && [ "$subnet_id" != "None" ]; then
        echo "  - Deleting Subnet: $subnet_id"
        aws ec2 delete-subnet --subnet-id $subnet_id --region $REGION 2>/dev/null || true
    fi
done

# 12. VPC 삭제
echo "12. Deleting VPC..."
if [ "$VPC_ID" != "" ]; then
    echo "  - Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION 2>/dev/null || true
fi

# 13. CloudWatch Log Groups 정리
echo "13. Cleaning up CloudWatch Log Groups..."
aws logs describe-log-groups --region $REGION --log-group-name-prefix "/ecs/${PROJECT}-${ENV}" --query 'logGroups[].logGroupName' --output text 2>/dev/null | while read log_group; do
    if [ ! -z "$log_group" ] && [ "$log_group" != "None" ]; then
        echo "  - Deleting Log Group: $log_group"
        aws logs delete-log-group --log-group-name "$log_group" --region $REGION 2>/dev/null || true
    fi
done

# 14. ECS Cluster 삭제
echo "14. Cleaning up ECS Cluster..."
aws ecs delete-cluster --cluster $CLUSTER_NAME --region $REGION 2>/dev/null || true

echo ""
echo "✅ Force cleanup completed!"
echo "⚠️  Please wait 5-10 minutes for AWS to propagate changes."
echo "📝 Then run: cd envs/dev && terraform destroy"
echo ""
echo "If terraform destroy still fails, run:"
echo "  ./scripts/cleanup-terraform-state.sh"