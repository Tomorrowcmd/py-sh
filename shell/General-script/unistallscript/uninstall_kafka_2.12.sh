#!/bin/bash

set -e

echo "====== 开始卸载 Kafka + Zookeeper ======"

KAFKA_HOME="/opt/kafka/kafka_2.12-2.8.2"
KAFKA_BASE="/opt/kafka"
SERVICE_KAFKA="kafka.service"
SERVICE_ZK="zookeeper.service"

##############################################
# 停止服务
##############################################
echo "== 停止 Kafka 和 Zookeeper 服务 =="

if systemctl list-units --full -all | grep -q "$SERVICE_KAFKA"; then
    systemctl stop $SERVICE_KAFKA || true
    systemctl disable $SERVICE_KAFKA || true
    echo "已停止并禁用 Kafka 服务"
else
    echo "Kafka 服务不存在，跳过"
fi

if systemctl list-units --full -all | grep -q "$SERVICE_ZK"; then
    systemctl stop $SERVICE_ZK || true
    systemctl disable $SERVICE_ZK || true
    echo "已停止并禁用 Zookeeper 服务"
else
    echo "Zookeeper 服务不存在，跳过"
fi

##############################################
# 删除 systemd 服务文件
##############################################
echo "== 删除 systemd 服务文件 =="

[ -f /etc/systemd/system/$SERVICE_KAFKA ] && rm -f /etc/systemd/system/$SERVICE_KAFKA
[ -f /etc/systemd/system/$SERVICE_ZK ] && rm -f /etc/systemd/system/$SERVICE_ZK

systemctl daemon-reload
echo "systemd 配置已刷新"

##############################################
# 删除 Kafka 目录
##############################################
echo "== 删除 Kafka 安装目录及数据目录 =="

if [ -d "$KAFKA_HOME" ]; then
    rm -rf "$KAFKA_HOME"
    echo "已删除目录：$KAFKA_HOME"
else
    echo "目录 $KAFKA_HOME 不存在，跳过"
fi

if [ -d "$KAFKA_BASE/kafka-logs" ]; then
    rm -rf "$KAFKA_BASE/kafka-logs"
    echo "已删除 Kafka 日志目录：$KAFKA_BASE/kafka-logs"
fi

if [ -d "$KAFKA_BASE/zookeeper-data" ]; then
    rm -rf "$KAFKA_BASE/zookeeper-data"
    echo "已删除 Zookeeper 数据目录：$KAFKA_BASE/zookeeper-data"
fi

echo "== 删除 Kafka 根目录（如空） =="
rmdir "$KAFKA_BASE" 2>/dev/null || true

##############################################
# 清理完成
##############################################
echo "====== Kafka + Zookeeper 卸载完成 ======"
echo "所有文件、服务、目录均已清理干净。"
