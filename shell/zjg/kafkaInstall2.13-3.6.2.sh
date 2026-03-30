#!/bin/bash
set -e  # 出错自动退出

# ================== 配置变量 ==================
KAFKA_VERSION="kafka_2.13-3.6.2"
INSTALL_DIR="/opt/kafka"
KAFKA_TAR="${KAFKA_VERSION}.tgz"
KAFKA_HOME="${INSTALL_DIR}/${KAFKA_VERSION}"
CONFIG_DIR="${KAFKA_HOME}/config"
SERVER_PROPERTIES="${CONFIG_DIR}/kraft/server.properties"
LOG_DIR="${INSTALL_DIR}/logs"
META_DIR="${INSTALL_DIR}/metadata"

# 获取本机IP（首个非回环IP）
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "本机IP地址为：${LOCAL_IP}"

# ================== 解压 Kafka ==================
mkdir -p "$INSTALL_DIR"
tar -zxvf "/opt/$KAFKA_TAR" -C "$INSTALL_DIR"
mkdir -p "$LOG_DIR" "$META_DIR"

# ================== 修改配置文件 ==================
echo "正在修改配置文件：${SERVER_PROPERTIES}..."

# 安全替换或追加配置的函数
set_config() {
    local key="$1"
    local value="$2"
    if grep -qE "^${key}=" "$SERVER_PROPERTIES"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$SERVER_PROPERTIES"
    else
        echo "${key}=${value}" >> "$SERVER_PROPERTIES"
    fi
}

# KRaft 必须配置
set_config "process.roles" "broker,controller"
set_config "node.id" "1"
set_config "controller.quorum.voters" "1@${LOCAL_IP}:9093"
set_config "listeners" "PLAINTEXT://0.0.0.0:9092,CONTROLLER://${LOCAL_IP}:9093"
set_config "advertised.listeners" "PLAINTEXT://${LOCAL_IP}:9092"
set_config "num.network.threads" "4"
set_config "num.recovery.threads.per.data.dir" "2"
set_config "log.dirs" "${LOG_DIR}"
set_config "metadata.log.dir" "${META_DIR}"

# 防重复追加刷盘配置
if ! grep -q "^log.flush.interval.messages=" "$SERVER_PROPERTIES"; then
    cat >> "$SERVER_PROPERTIES" <<EOF
log.flush.interval.messages=5000
log.flush.interval.ms=1000
EOF
fi

echo "配置文件修改完成！"

# ================== 修改权限 ==================
chown -R root:root "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

# ================== 初始化元数据 ==================
echo "准备初始化 Kafka 元数据..."
cd "$KAFKA_HOME"

# 检查元数据目录是否为空
if [ -z "$(ls -A "$META_DIR" 2>/dev/null)" ]; then
    bin/kafka-storage.sh format -t $(bin/kafka-storage.sh random-uuid) -c "$SERVER_PROPERTIES"
    echo "=================== 元数据初始化完成！ ==================="
else
    echo "元数据目录非空，跳过初始化。"
fi

# ================== 创建 Systemd 自启动 ==================
SERVICE_FILE="/etc/systemd/system/kafka.service"
echo "正在创建 Kafka Systemd 服务文件：$SERVICE_FILE"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Apache Kafka Server (KRaft mode)
After=network.target

[Service]
Type=simple
User=root
ExecStart=${KAFKA_HOME}/bin/kafka-server-start.sh ${SERVER_PROPERTIES}
Restart=on-failure
WorkingDirectory=${KAFKA_HOME}
StandardOutput=journal
StandardError=journal
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd，启用并启动 Kafka
systemctl daemon-reload
systemctl enable kafka
systemctl restart kafka
#systemctl status kafka

echo "Kafka 已设置自启动并启动成功！"







# 配置模板
############################## Server Basics #############################
#process.roles=broker,controller
#node.id=1
#controller.quorum.voters=1@192.168.37.128:9093
#
############################## Socket Server Settings #############################
#listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://192.168.37.128:9093
#inter.broker.listener.name=PLAINTEXT
#advertised.listeners=PLAINTEXT://192.168.37.128:9092
#controller.listener.names=CONTROLLER
#listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
#
#num.network.threads=4         # 调整网络线程
#num.io.threads=8              # IO线程数，适合单盘环境
#socket.send.buffer.bytes=131072
#socket.receive.buffer.bytes=131072
#socket.request.max.bytes=104857600
#
############################## Log Basics #############################
#log.dirs=/opt/kafka/logs
#metadata.log.dir=/opt/kafka/metadata
#num.partitions=1
#num.recovery.threads.per.data.dir=2   # 提高日志恢复速度
#
############################## Internal Topic Settings  #############################
#offsets.topic.replication.factor=1
#transaction.state.log.replication.factor=1
#transaction.state.log.min.isr=1
#
############################## Log Retention & Flush #############################
#log.retention.hours=168
#log.segment.bytes=1073741824
#log.retention.check.interval.ms=300000
#log.flush.interval.messages=5000         # 每 5000 条消息强制刷盘
#log.flush.interval.ms=1000               # 每 1 秒强制刷盘


# 测试手动启动方式
# bin/kafka-server-start.sh config/kraft/server.properties
# 后台启动
# nohup bin/kafka-server-start.sh config/kraft/server.properties > /data/kafka/logs/kafka.log 2>&1 &

# 验证 Kafka 是否可用

# 查看 broker 列表
# bin/kafka-broker-api-versions.sh --bootstrap-server 192.168.37.128:9092

# 测试 Topic 与消息
# 创建 topic
#bin/kafka-topics.sh --create --topic test-topic --bootstrap-server 192.168.37.128:9092 --partitions 1 --replication-factor 1
#
## 查看 topic
#bin/kafka-topics.sh --list --bootstrap-server 192.168.37.128:9092
#
## 生产消息
#echo "Hello KRaft Kafka" | bin/kafka-console-producer.sh --topic test-topic --bootstrap-server 192.168.37.128:9092
#
## 消费消息
#bin/kafka-console-consumer.sh --topic test-topic --from-beginning --bootstrap-server 192.168.37.128:9092

# 能正常发送和消费消息，说明 Kafka 部署成功。




