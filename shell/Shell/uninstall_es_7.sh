#!/bin/bash

set -e

SERVICE_NAME="elasticsearch.service"
ES_DIR="/opt/elasticsearch-7.15.2"
ES_USER="elasticsearch"

echo "=== 停止 Elasticsearch 服务 ==="
if systemctl list-units --full -all | grep -q "$SERVICE_NAME"; then
    systemctl stop $SERVICE_NAME || true
    systemctl disable $SERVICE_NAME || true
else
    echo "Elasticsearch 服务未找到，跳过停止步骤。"
fi

echo "=== 删除 systemd 服务文件 ==="
if [ -f /etc/systemd/system/$SERVICE_NAME ]; then
    rm -f /etc/systemd/system/$SERVICE_NAME
    echo "已删除：/etc/systemd/system/$SERVICE_NAME"
else
    echo "服务文件不存在，跳过。"
fi

echo "=== 清理 systemctl 配置 ==="
systemctl daemon-reload

echo "=== 删除 Elasticsearch 安装目录 ==="
if [ -d "$ES_DIR" ]; then
    rm -rf "$ES_DIR"
    echo "已删除目录：$ES_DIR"
else
    echo "目录 $ES_DIR 不存在，跳过。"
fi

echo "=== 删除 Elasticsearch 用户 ==="
if id "$ES_USER" &>/dev/null; then
    userdel -r $ES_USER || true
    echo "已删除用户：$ES_USER"
else
    echo "用户不存在，跳过"
fi

echo "=== 清理 /etc/security/limits.conf 中的 ES 配置 ==="
sed -i '/elasticsearch soft memlock unlimited/d' /etc/security/limits.conf
sed -i '/elasticsearch hard memlock unlimited/d' /etc/security/limits.conf

echo "=== 卸载完成 ==="
echo "Elasticsearch 已彻底卸载。"
