#!/bin/bash
# Kafka KRaft User Data Script - Terraform Template
# Environment: ${environment}
# Node ID: ${node_id}
# Cluster ID: ${cluster_id}

set -e

# 로그 설정
exec > >(tee /var/log/kafka-setup.log)
exec 2>&1

echo "=== Kafka ${environment} Setup Started at $(date) ==="
echo "Node ID: ${node_id}, Cluster ID: ${cluster_id}"

# 변수 설정
NODE_ID="${node_id}"
CLUSTER_ID="${cluster_id}"
ENVIRONMENT="${environment}"
NODE_COUNT="${node_count}"
KAFKA_VERSION="4.1.1"
SCALA_VERSION="2.13"
KAFKA_USER="kafka"
KAFKA_HOME="/opt/kafka"
JAVA_HOME="/usr/lib/jvm/java-17-amazon-corretto"

# 시스템 업데이트
echo "Updating system packages..."
yum update -y

# 필수 패키지 설치
echo "Installing required packages..."
yum install -y \
    java-17-amazon-corretto-headless \
    wget \
    tar \
    gzip \
    net-tools \
    htop \
    iotop \
    sysstat \
    amazon-cloudwatch-agent \
    awscli

# Java 버전 확인
echo "Java version:"
java -version

# 데이터 볼륨 마운트
echo "Setting up data volume..."
if [ -b /dev/nvme1n1 ]; then
    DEVICE="/dev/nvme1n1"
elif [ -b /dev/xvdf ]; then
    DEVICE="/dev/xvdf"
else
    echo "Data volume not found!"
    exit 1
fi

# 파일시스템 생성 및 마운트
if ! blkid $DEVICE; then
    echo "Creating filesystem on $DEVICE..."
    mkfs -t xfs $DEVICE
fi

mkdir -p $KAFKA_HOME
mount $DEVICE $KAFKA_HOME

# fstab에 추가
DEVICE_UUID=$(blkid -s UUID -o value $DEVICE)
echo "UUID=$DEVICE_UUID $KAFKA_HOME xfs defaults,nofail 0 2" >> /etc/fstab

# Kafka 사용자 생성
echo "Creating kafka user..."
if ! id "$KAFKA_USER" &>/dev/null; then
    useradd -r -s /bin/false -d $KAFKA_HOME $KAFKA_USER
fi

chown -R $KAFKA_USER:$KAFKA_USER $KAFKA_HOME

# Kafka 다운로드 및 설치
echo "Downloading Kafka $KAFKA_VERSION..."
cd /tmp
wget -q https://downloads.apache.org/kafka/$${KAFKA_VERSION}/kafka_$${SCALA_VERSION}-$${KAFKA_VERSION}.tgz

echo "Extracting Kafka..."
tar -xzf kafka_$${SCALA_VERSION}-$${KAFKA_VERSION}.tgz -C /opt/
mv /opt/kafka_$${SCALA_VERSION}-$${KAFKA_VERSION} /opt/kafka-$${KAFKA_VERSION}
ln -sf /opt/kafka-$${KAFKA_VERSION} /opt/kafka-current

chown -R $KAFKA_USER:$KAFKA_USER /opt/kafka-$${KAFKA_VERSION} /opt/kafka-current

# Kafka 디렉토리 생성
echo "Creating Kafka directories..."
mkdir -p $KAFKA_HOME/{logs,config,scripts,ssl}
mkdir -p /var/log/kafka
chown -R $KAFKA_USER:$KAFKA_USER $KAFKA_HOME /var/log/kafka

# Private IP 가져오기
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
HOSTNAME="kafka-${environment}-$NODE_ID"

echo "Node configuration: ID=$NODE_ID, IP=$PRIVATE_IP, Hostname=$HOSTNAME"

# 환경별 설정 생성
if [ "$ENVIRONMENT" = "dev" ]; then
    # Dev 환경 설정 (단일 노드)
    cat > $KAFKA_HOME/config/server.properties << EOF
# Kafka Dev Configuration
node.id=$NODE_ID
process.roles=broker,controller
controller.quorum.voters=$NODE_ID@$PRIVATE_IP:9094

# Listeners
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9094
advertised.listeners=PLAINTEXT://$PRIVATE_IP:9092
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT

# Log directories
log.dirs=$KAFKA_HOME/logs

# Cluster ID
cluster.id=$CLUSTER_ID

# Dev environment settings (single node, no replication)
default.replication.factor=1
min.insync.replicas=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1

# Log retention (short for dev)
log.retention.hours=12
log.retention.bytes=52428800
log.segment.bytes=52428800

# Compression
compression.type=snappy

# Performance tuning for t3.micro
num.network.threads=2
num.io.threads=4
socket.send.buffer.bytes=65536
socket.receive.buffer.bytes=65536
socket.request.max.bytes=104857600
EOF

    # JVM 설정 (t3.micro용)
    cat > $KAFKA_HOME/config/jvm.conf << 'EOF'
# JVM settings for t3.micro (1GB RAM)
-Xmx400M
-Xms400M
-XX:+UseG1GC
-XX:MaxGCPauseMillis=20
-XX:InitiatingHeapOccupancyPercent=35
-XX:+ExplicitGCInvokesConcurrent
-XX:MaxInlineLevel=15
-Djava.awt.headless=true
-Dcom.sun.management.jmxremote=true
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.port=9999
EOF

else
    # Prod 환경 설정 (3노드 클러스터)
    cat > $KAFKA_HOME/config/server.properties << EOF
# Kafka Production Configuration - Node $NODE_ID
node.id=$NODE_ID
process.roles=broker,controller
controller.quorum.voters=1@kafka-prod-1:9094,2@kafka-prod-2:9094,3@kafka-prod-3:9094

# Listeners
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9094
advertised.listeners=PLAINTEXT://$PRIVATE_IP:9092
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT

# Log directories
log.dirs=$KAFKA_HOME/logs

# Cluster ID
cluster.id=$CLUSTER_ID

# Production replication settings
default.replication.factor=3
min.insync.replicas=2
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2

# Log retention settings
log.retention.hours=168
log.retention.bytes=1073741824
log.segment.bytes=1073741824

# Compression
compression.type=snappy

# Performance tuning for t3.small (2GB RAM)
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

# Background threads
num.replica.fetchers=1
num.recovery.threads.per.data.dir=1

# Log cleaner
log.cleaner.enable=true
log.cleaner.threads=1

# Group coordinator
group.initial.rebalance.delay.ms=3000

# Controller
controller.socket.timeout.ms=30000
controller.message.queue.size=10

# Replica lag
replica.lag.time.max.ms=30000
replica.socket.timeout.ms=30000
replica.socket.receive.buffer.bytes=65536

# Producer/Consumer
fetch.purgatory.purge.interval.requests=1000
producer.purgatory.purge.interval.requests=1000
EOF

    # JVM 설정 (t3.small용)
    cat > $KAFKA_HOME/config/jvm.conf << EOF
# JVM settings for t3.small (2GB RAM)
-Xmx1G
-Xms1G
-XX:+UseG1GC
-XX:MaxGCPauseMillis=20
-XX:InitiatingHeapOccupancyPercent=35
-XX:+ExplicitGCInvokesConcurrent
-XX:MaxInlineLevel=15
-XX:+UnlockExperimentalVMOptions
-XX:+UseJVMCICompiler
-Djava.awt.headless=true
-Dcom.sun.management.jmxremote=true
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.port=9999
-Dcom.sun.management.jmxremote.rmi.port=9999
-Djava.rmi.server.hostname=$PRIVATE_IP
EOF
fi

# 환경 변수 설정
echo "Setting up environment variables..."
cat > /etc/profile.d/kafka.sh << EOF
export JAVA_HOME=$JAVA_HOME
export KAFKA_HOME=$KAFKA_HOME
export PATH=\$PATH:\$KAFKA_HOME/bin
EOF

# Kafka 시작 스크립트 생성
echo "Creating Kafka startup script..."
if [ "$ENVIRONMENT" = "dev" ]; then
    HEAP_OPTS="-Xmx400M -Xms400M"
else
    HEAP_OPTS="-Xmx1G -Xms1G"
fi

cat > $KAFKA_HOME/scripts/start-kafka.sh << EOF
#!/bin/bash
export JAVA_HOME=$JAVA_HOME
export KAFKA_HOME=$KAFKA_HOME
export KAFKA_HEAP_OPTS="$HEAP_OPTS"
export KAFKA_JVM_PERFORMANCE_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35"
export JMX_PORT=9999

cd \$KAFKA_HOME
exec \$KAFKA_HOME/bin/kafka-server-start.sh \$KAFKA_HOME/config/server.properties
EOF

chmod +x $KAFKA_HOME/scripts/start-kafka.sh
chown $KAFKA_USER:$KAFKA_USER $KAFKA_HOME/scripts/start-kafka.sh

# 스토리지 포맷
echo "Formatting Kafka storage..."
if [ "$ENVIRONMENT" = "prod" ] && [ "$NODE_ID" != "1" ]; then
    # Prod 환경에서 첫 번째 노드가 아닌 경우 대기
    echo "Waiting for primary node to be ready..."
    sleep 60
fi

sudo -u $KAFKA_USER /opt/kafka-current/bin/kafka-storage.sh format \
    -t $CLUSTER_ID \
    -c $KAFKA_HOME/config/server.properties

# systemd 서비스 파일 생성
echo "Creating systemd service..."
cat > /etc/systemd/system/kafka.service << EOF
[Unit]
Description=Apache Kafka Server (KRaft mode) - $ENVIRONMENT Node $NODE_ID
Documentation=https://kafka.apache.org/documentation/
Requires=network.target
After=network.target

[Service]
Type=simple
User=$KAFKA_USER
Group=$KAFKA_USER
Environment=JAVA_HOME=$JAVA_HOME
Environment=KAFKA_HOME=$KAFKA_HOME
Environment=KAFKA_HEAP_OPTS=$HEAP_OPTS
Environment=KAFKA_JVM_PERFORMANCE_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=20
Environment=JMX_PORT=9999
ExecStart=$KAFKA_HOME/scripts/start-kafka.sh
ExecStop=/opt/kafka-current/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10
TimeoutStopSec=30

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kafka

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# 시스템 최적화
echo "Applying system optimizations..."
cat >> /etc/sysctl.conf << 'EOF'
# Kafka optimizations
vm.swappiness=1
vm.dirty_background_ratio=5
vm.dirty_ratio=60
vm.dirty_expire_centisecs=12000
vm.max_map_count=262144
net.core.rmem_default=262144
net.core.rmem_max=16777216
net.core.wmem_default=262144
net.core.wmem_max=16777216
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_rmem=4096 65536 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF

sysctl -p

# 파일 디스크립터 제한 증가
echo "Setting file descriptor limits..."
cat >> /etc/security/limits.conf << 'EOF'
kafka soft nofile 100000
kafka hard nofile 100000
kafka soft nproc 32768
kafka hard nproc 32768
EOF

# CloudWatch 에이전트 설정
echo "Setting up CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "metrics": {
        "namespace": "Kafka/$ENVIRONMENT",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["/opt/kafka"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/kafka-setup.log",
                        "log_group_name": "/aws/ec2/kafka-$ENVIRONMENT",
                        "log_stream_name": "{instance_id}/setup.log"
                    }
                ]
            }
        }
    }
}
EOF

# CloudWatch 에이전트 시작
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# 서비스 등록 및 시작
echo "Starting Kafka service..."
systemctl daemon-reload
systemctl enable kafka

# 노드별 시차를 두고 시작 (클러스터 안정성)
if [ "$ENVIRONMENT" = "prod" ]; then
    DELAY=$(($NODE_ID * 30))
    echo "Waiting $DELAY seconds before starting (node $NODE_ID)..."
    sleep $DELAY
fi

systemctl start kafka

# 서비스 상태 확인
sleep 15
systemctl status kafka

# 유용한 스크립트 생성
echo "Creating utility scripts..."

# 상태 확인 스크립트
cat > $KAFKA_HOME/scripts/status.sh << 'EOF'
#!/bin/bash
echo "=== Kafka Status ==="
systemctl status kafka --no-pager

echo -e "\n=== Kafka Processes ==="
ps aux | grep kafka | grep -v grep

echo -e "\n=== Topics ==="
/opt/kafka-current/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 2>/dev/null || echo "Cannot list topics"

echo -e "\n=== Disk Usage ==="
df -h /opt/kafka

echo -e "\n=== Memory Usage ==="
free -h

echo -e "\n=== Network Connections ==="
netstat -tlnp | grep -E ':(9092|9094|9999)'
EOF

chmod +x $KAFKA_HOME/scripts/status.sh
chown $KAFKA_USER:$KAFKA_USER $KAFKA_HOME/scripts/status.sh

# 첫 번째 노드에서만 기본 토픽 생성 (Prod 환경)
if [ "$ENVIRONMENT" = "prod" ] && [ "$NODE_ID" = "1" ]; then
    echo "Creating production topics (primary node)..."
    sleep 60  # 클러스터 완전 시작 대기
    
    sudo -u $KAFKA_USER /opt/kafka-current/bin/kafka-topics.sh \
        --create \
        --topic order-events \
        --bootstrap-server localhost:9092 \
        --partitions 6 \
        --replication-factor 3 \
        --config min.insync.replicas=2 \
        --config retention.hours=168 || echo "Topic creation failed"
        
elif [ "$ENVIRONMENT" = "dev" ]; then
    echo "Creating dev topics..."
    sleep 30
    
    sudo -u $KAFKA_USER /opt/kafka-current/bin/kafka-topics.sh \
        --create \
        --topic test-topic \
        --bootstrap-server localhost:9092 \
        --partitions 1 \
        --replication-factor 1 || echo "Topic creation failed"
fi

# 완료 표시
echo "=== Kafka $ENVIRONMENT Setup Completed Successfully at $(date) ==="
echo "Node ID: $NODE_ID"
echo "Cluster ID: $CLUSTER_ID"
echo "Kafka is running on port 9092"
echo "Setup log: /var/log/kafka-setup.log"

# 설치 완료 마커 파일 생성
touch /tmp/kafka-setup-complete
echo "Node $NODE_ID setup completed at $(date)" > /tmp/kafka-setup-complete