#!/bin/bash
set -e  # 出错自动退出
cd /opt

# Kafka 压缩包
kafka_tar="kafka_2.12-2.8.2.tgz"

# 解压
mkdir -p /opt/kafka
tar -xvzf ${kafka_tar} -C /opt/kafka
cd /opt/kafka/kafka_2.12-2.8.2

# 创建日志与数据目录
mkdir -p /opt/kafka/kafka-logs
mkdir -p /opt/kafka/zookeeper-data

# 配置文件路径
CONFIG_DIR="/opt/kafka/kafka_2.12-2.8.2/config"
KAFKA_CONF="${CONFIG_DIR}/server.properties"
ZK_CONF="${CONFIG_DIR}/zookeeper.properties"

# 获取本机 IP
# LOCAL_IP=$(hostname -I | awk '{print $1}')
LOCAL_IP="127.0.0.1"
echo "本机IP地址为：${LOCAL_IP}"    

echo "正在修改 Kafka 配置文件: ${KAFKA_CONF}"

# 修改 advertised.listeners
if grep -q "^#\s*advertised.listeners=" "$KAFKA_CONF"; then
    sed -i "s|^#\s*advertised.listeners=.*|advertised.listeners=PLAINTEXT://${LOCAL_IP}:9092|" "$KAFKA_CONF"
elif grep -q "^advertised.listeners=" "$KAFKA_CONF"; then
    # 如果配置已经存在且没有注释，直接修改
    sed -i "s|^advertised.listeners=.*|advertised.listeners=PLAINTEXT://${LOCAL_IP}:9092|" "$KAFKA_CONF"
else
    # 如果配置不存在，直接添加
    echo "advertised.listeners=PLAINTEXT://${LOCAL_IP}:9092" >> "$KAFKA_CONF"
fi

# 修改 log.dirs
if grep -q "^log.dirs=" "$KAFKA_CONF"; then
    sed -i "s|^log.dirs=.*|log.dirs=/opt/kafka/kafka-logs|" "$KAFKA_CONF"
else
    echo "log.dirs=/opt/kafka/kafka-logs" >> "$KAFKA_CONF"
fi

# 修改 zookeeper 数据路径
if grep -q "^dataDir=" "$ZK_CONF"; then
    sed -i "s|^dataDir=.*|dataDir=/opt/kafka/zookeeper-data|" "$ZK_CONF"
else
    echo "dataDir=/opt/kafka/zookeeper-data" >> "$ZK_CONF"
fi

echo "Kafka 配置完成 ✅"
echo "   - advertised.listeners=PLAINTEXT://${LOCAL_IP}:9092"
echo "   - log.dirs=/opt/kafka/kafka-logs"
echo "   - dataDir=/opt/kafka/zookeeper-data"

###############################################
#           创建 systemd 自启动服务
###############################################
echo "配置 Kafka 和 Zookeeper 的 systemd 自启服务..."

# === Zookeeper 服务 ===
cat > /etc/systemd/system/zookeeper.service <<EOF
[Unit]
Description=Apache Zookeeper Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/kafka/kafka_2.12-2.8.2/bin/zookeeper-server-start.sh /opt/kafka/kafka_2.12-2.8.2/config/zookeeper.properties
ExecStop=/opt/kafka/kafka_2.12-2.8.2/bin/zookeeper-server-stop.sh
Restart=on-abnormal
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# === Kafka 服务 ===
cat > /etc/systemd/system/kafka.service <<EOF
[Unit]
Description=Apache Kafka Service
After=zookeeper.service
Requires=zookeeper.service

[Service]
Type=simple
User=root
ExecStart=/opt/kafka/kafka_2.12-2.8.2/bin/kafka-server-start.sh /opt/kafka/kafka_2.12-2.8.2/config/server.properties
ExecStop=/opt/kafka/kafka_2.12-2.8.2/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 并启用服务
systemctl daemon-reload
# systemctl enable zookeeper
# systemctl enable kafka

# 可选：立即启动服务
systemctl start zookeeper
sleep 5
systemctl start kafka

echo "✅ Kafka 与 Zookeeper 已安装并设置为开机自启"
echo "使用以下命令查看状态："
echo "  systemctl status zookeeper"
echo "  systemctl status kafka"






# 验证测试
# cd /opt/kafka/kafka_2.12-2.8.2

# 创建一个测试 Topic
# bin/kafka-topics.sh --create \
#   --topic test-topic \
#   --bootstrap-server localhost:9092 \
#   --partitions 1 \
#   --replication-factor 1
# 如果创建成功，会显示：Created topic test-topic.

# 查看当前 Topic 列表：
# bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# 应该能看到：
# test-topic


# 启动一个生产者（发送消息）：
# bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test-topic
# 会进入交互模式，输入几行文字，例如输入几个字符串：
# hello kafka
# this is a test
# 输入完之后按下 Ctrl + C 退出

# 启动一个消费者（接收消息）
# bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test-topic --from-beginning
# 如果一切正常，你会看到刚才发送的内容：
# hello kafka
# this is a test


