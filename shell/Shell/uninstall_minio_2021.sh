#!/bin/bash

echo "========================================"
echo "   MinIO 旧版（2021）卸载脚本开始运行 "
echo "========================================"

### ----------------------------
### 1. 停止 MinIO 服务
### ----------------------------
echo "▶ 停止 MinIO 服务 ..."

systemctl stop minio 2>/dev/null
systemctl disable minio 2>/dev/null

### ----------------------------
### 2. 删除 systemd 服务文件
### ----------------------------
SERVER_FILE="/etc/systemd/system/minio.service"
if [ -f "$SERVER_FILE" ]; then
    echo "▶ 删除 MinIO systemd 服务文件 ..."
    rm -f "$SERVER_FILE"
else
    echo "▶ MinIO systemd 服务文件不存在，跳过删除。"
fi

### ----------------------------
### 3. 删除环境变量文件
### ----------------------------
ENV_FILE="/etc/default/minio"
if [ -f "$ENV_FILE" ]; then
    echo "▶ 删除 MinIO 环境变量文件 ..."
    rm -f "$ENV_FILE"
else
    echo "▶ MinIO 环境变量文件不存在，跳过删除。"
fi

### ----------------------------
### 4. 卸载 MinIO rpm 包
### ----------------------------
echo "▶ 检查 MinIO 是否通过 RPM 安装 ..."

RPM_NAME=$(rpm -qa | grep -E '^minio-0\.0' | head -n 1)

if [ -n "$RPM_NAME" ]; then
    echo "▶ 卸载 MinIO RPM 包: $RPM_NAME ..."
    rpm -e "$RPM_NAME"
else
    echo "▶ 未检测到 MinIO RPM 包，跳过卸载。"
fi

### ----------------------------
### 5. 删除可执行文件（如果仍残留）
### ----------------------------
BIN1="/usr/local/bin/minio"
BIN2="/usr/bin/minio"

if [ -f "$BIN1" ]; then
    echo "▶ 删除 MinIO 可执行文件: $BIN1 ..."
    rm -f "$BIN1"
fi

if [ -f "$BIN2" ]; then
    echo "▶ 删除 MinIO 可执行文件: $BIN2 ..."
    rm -f "$BIN2"
fi

### ----------------------------
### 6. 删除数据目录（可选：强制删除）
### ----------------------------
DATA_DIR="/opt/minio"

if [ -d "$DATA_DIR" ]; then
    echo "▶ 检测到 MinIO 数据目录: $DATA_DIR"
    # shell内置的read命，读取用户输入，confirm存储用户输入的变量名
    read -p "是否删除数据目录？(y/N): " confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "▶ 删除 MinIO 数据目录 ..."
        rm -rf "$DATA_DIR"
    else
        echo "✔ 保留数据目录"
    fi
else
    echo "✔ 数据目录不存在，跳过"
fi

### ----------------------------
### 7. systemd 重载
### ----------------------------
echo "▶ 刷新 systemd ..."
systemctl daemon-reload

### ----------------------------
### 8. 清理日志（旧版不会自动生成太多日志）
### ----------------------------

echo "▶ 清理 MinIO 日志 ..."
journalctl --rotate
journalctl --vacuum-time=1s

echo "========================================"
echo "   ✔ MinIO 已完全卸载（旧版 2021）"
echo "========================================"