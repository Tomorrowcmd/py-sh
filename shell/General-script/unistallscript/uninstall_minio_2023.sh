#!/bin/bash

echo "=============================================="
echo "     MinIO 卸载脚本（2023 版本）开始运行"
echo "=============================================="


### ----------------------------
### 1. 停止并禁用 MinIO 服务
### ----------------------------
echo "▶ 停止 MinIO 服务 ..."
systemctl stop minio.service 2>/dev/null
systemctl disable minio.service 2>/dev/null



### ----------------------------
### 2. 删除 systemd 服务文件
### ----------------------------
SERVICE_FILE="/etc/systemd/system/minio.service"

if [ -f "$SERVICE_FILE" ]; then
    echo "▶ 删除 systemd 服务文件：$SERVICE_FILE"
    rm -f "$SERVICE_FILE"
else
    echo "✔ 未找到 systemd 服务文件，跳过"
fi

### ----------------------------
### 3. 删除环境变量文件
### ----------------------------
ENV_FILE="/etc/default/minio"

if [ -f "$ENV_FILE" ]; then
    echo "▶ 删除环境变量文件：$ENV_FILE"
    rm -f "$ENV_FILE"
else
    echo "✔ 未找到环境变量文件，跳过"
fi


### ----------------------------
### 4. 卸载 MinIO RPM 包
### ----------------------------
echo "▶ 检查系统中的 MinIO RPM 包 ..."

RPM_NAME=$(rpm -qa | grep -E '^minio-' | head -n 1)

if [ -n "$RPM_NAME" ]; then
    echo "▶ 卸载 MinIO RPM 包：$RPM_NAME"
    rpm -e "$RPM_NAME"
else
    echo "✔ 未检测到通过 RPM 安装的 MinIO，跳过"
fi


### ----------------------------
### 5. 删除可执行文件（如果残留）
### ----------------------------
BIN="/usr/local/bin/minio"

if [ -f "$BIN" ]; then
    echo "▶ 删除二进制文件：$BIN"
    rm -f "$BIN"
else
    echo "✔ MinIO 可执行文件不存在，跳过"
fi


### ----------------------------
### 6. 删除 MinIO 数据目录（带提示）
### ----------------------------
DATA_DIR="/data/minio"

if [ -d "$DATA_DIR" ]; then
    echo "▶ 检测到 MinIO 数据目录：$DATA_DIR"
    read -p "是否删除数据目录？(y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "▶ 正在删除数据目录 ..."
        rm -rf "$DATA_DIR"
    else
        echo "✔ 数据目录已保留"
    fi
else
    echo "✔ 数据目录不存在，跳过"
fi

### ----------------------------
### 7. 刷新 systemd 配置
### ----------------------------
echo "▶ 刷新 systemd ..."
systemctl daemon-reload


### ----------------------------
### 8. 清理日志（可选）
### ----------------------------
echo "▶ 清理 MinIO 日志 ..."
journalctl --rotate
journalctl --vacuum-time=1s

echo "=============================================="
echo "      ✔ MinIO（2023版） 已完全卸载完毕"
echo "=============================================="
