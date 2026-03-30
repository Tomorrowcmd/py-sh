#!/bin/bash
set -e  # 出错自动退出

# ================== 配置变量（与安装脚本保持一致） ==================
KAFKA_VERSION="kafka_2.13-3.6.2"
INSTALL_DIR="/opt/kafka"
KAFKA_HOME="${INSTALL_DIR}/${KAFKA_VERSION}"
SERVICE_FILE="/etc/systemd/system/kafka.service"

echo "========== 开始卸载 Kafka =========="

# ================== 停止并禁用 Kafka 服务 ==================
if systemctl list-unit-files | grep -q "^kafka.service"; then
    echo "停止 Kafka 服务..."
    systemctl stop kafka || true

    echo "禁用 Kafka 自启动..."
    systemctl disable kafka || true
else
    echo "Kafka 服务未注册，跳过 systemd 服务停止步骤。"
fi

# ================== 删除 systemd 服务文件 ==================
if [ -f "$SERVICE_FILE" ]; then
    echo "删除 Kafka systemd 服务文件：$SERVICE_FILE"
    rm -rf "$SERVICE_FILE"

    echo "重新加载 systemd..."
    systemctl daemon-reload
else
    echo "Kafka systemd 服务文件不存在，跳过。"
fi

# ================== 删除 Kafka 安装目录 ==================
if [ -d "$INSTALL_DIR" ]; then
    echo "删除 Kafka 安装目录：$INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
else
    echo "Kafka 安装目录不存在，跳过。"
fi

# ================== 校验卸载结果 ==================
echo "========== 卸载完成，开始校验 =========="

if systemctl list-unit-files | grep -q kafka.service; then
    echo "⚠️  Kafka service 仍然存在，请检查！"
else
    echo "✅ Kafka systemd 服务已移除"
fi

if [ -d "$INSTALL_DIR" ]; then
    echo "⚠️  Kafka 目录仍存在：$INSTALL_DIR"
else
    echo "✅ Kafka 目录已清理"
fi

echo "========== Kafka 卸载完成 =========="
