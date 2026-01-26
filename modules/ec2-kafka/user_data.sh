#!/bin/bash
# Minimal Kafka Bootstrap Script
set -e

# 로그 설정
exec > >(tee /var/log/kafka-bootstrap.log)
exec 2>&1

echo "=== Kafka ${environment} Bootstrap Started at $(date) ==="
echo "Node ID: ${node_id}, Cluster ID: ${cluster_id}"

# 변수 설정
NODE_ID="${node_id}"
CLUSTER_ID="${cluster_id}"
ENVIRONMENT="${environment}"
KAFKA_USER="kafka"
KAFKA_HOME="/opt/kafka"

# 시스템 업데이트 및 Java 설치
yum update -y
yum install -y java-17-amazon-corretto-headless wget tar

# Kafka 사용자 생성
useradd -r -s /bin/false -d $KAFKA_HOME $KAFKA_USER || true

# 데이터 볼륨 설정
if [ -b /dev/nvme1n1 ]; then
    DEVICE="/dev/nvme1n1"
elif [ -b /dev/xvdf ]; then
    DEVICE="/dev/xvdf"
else
    echo "Data volume not found!"
    exit 1
fi

if ! blkid $DEVICE; then
    mkfs -t xfs $DEVICE
fi

mkdir -p $KAFKA_HOME
mount $DEVICE $KAFKA_HOME
chown -R $KAFKA_USER:$KAFKA_USER $KAFKA_HOME

# fstab에 추가
DEVICE_UUID=$(blkid -s UUID -o value $DEVICE)
echo "UUID=$DEVICE_UUID $KAFKA_HOME xfs defaults,nofail 0 2" >> /etc/fstab

# Kafka 다운로드 및 설치
cd /tmp
wget -q https://downloads.apache.org/kafka/4.1.1/kafka_2.13-4.1.1.tgz
tar -xzf kafka_2.13-4.1.1.tgz -C /opt/
mv /opt/kafka_2.13-4.1.1 /opt/kafka-4.1.1
ln -sf /opt/kafka-4.1.1 /opt/kafka-current
chown -R $KAFKA_USER:$KAFKA_USER /opt/kafka-4.1.1 /opt/kafka-current

# 기본 디렉터리 생성
mkdir -p $KAFKA_HOME/{logs,config}
chown -R $KAFKA_USER:$KAFKA_USER $KAFKA_HOME

# Private IP 가져오기
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# 기본 Kafka 설정 생성
cat > $KAFKA_HOME/config/server.properties << EOF
node.id=$NODE_ID
process.roles=broker,controller
controller.quorum.voters=$NODE_ID@$PRIVATE_IP:9094

listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9094
advertised.listeners=PLAINTEXT://$PRIVATE_IP:9092
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT
controller.listener.names=CONTROLLER
inter.broker.listener.name=PLAINTEXT

log.dirs=$KAFKA_HOME/logs
cluster.id=$CLUSTER_ID

# Dev environment settings
default.replication.factor=1
min.insync.replicas=1
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1

log.retention.hours=12
compression.type=snappy
EOF

chown $KAFKA_USER:$KAFKA_USER $KAFKA_HOME/config/server.properties

# 스토리지 포맷
sudo -u $KAFKA_USER /opt/kafka-current/bin/kafka-storage.sh format \
    -t $CLUSTER_ID \
    -c $KAFKA_HOME/config/server.properties

# systemd 서비스 생성
cat > /etc/systemd/system/kafka.service << EOF
[Unit]
Description=Apache Kafka Server (KRaft mode) - $ENVIRONMENT Node $NODE_ID
After=network.target

[Service]
Type=simple
User=$KAFKA_USER
Group=$KAFKA_USER
Environment=JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto
Environment=KAFKA_HOME=$KAFKA_HOME
ExecStart=/opt/kafka-current/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties
ExecStop=/opt/kafka-current/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 서비스 시작
systemctl daemon-reload
systemctl enable kafka
systemctl start kafka

echo "=== Kafka Bootstrap Completed at $(date) ==="
touch /tmp/kafka-bootstrap-complete