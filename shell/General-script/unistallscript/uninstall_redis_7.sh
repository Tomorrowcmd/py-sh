#!/bin/bash

echo "==========================================="
echo "        Redis 7.0.15 卸载脚本开始运行"
echo "==========================================="

### ---------------------------------------------------
### 1. 停止并禁用 Redis 服务
### ---------------------------------------------------
echo "▶ 停止 Redis 服务 ..."
systemctl stop redis.service 2>/dev/null
systemctl disable redis.service 2>/dev/null


### ---------------------------------------------------
### 2. 删除 systemd 服务文件
### ---------------------------------------------------
SERVICE_FILE="/etc/systemd/system/redis.service"

if [ -f "$SERVICE_FILE" ]; then
    echo "▶ 删除 systemd 服务文件：$SERVICE_FILE"
    rm -f "$SERVICE_FILE"
else
    echo "✔ 未找到 redis.service，跳过"
fi


### ---------------------------------------------------
### 3. 删除 Redis 配置目录
### ---------------------------------------------------
CONF_DIR="/etc/redis"

if [ -d "$CONF_DIR" ]; then
    echo "▶ 检测到配置目录：$CONF_DIR"
    read -p "是否删除 Redis 配置目录？(y/N): " confirm_conf

    if [[ "$confirm_conf" == "y" || "$confirm_conf" == "Y" ]]; then
        echo "▶ 删除配置目录 ..."
        rm -rf "$CONF_DIR"
    else
        echo "✔ Redis 配置目录已保留"
    fi
else
    echo "✔ 配置目录不存在，跳过"
fi


### ---------------------------------------------------
### 4. 删除通过 make install 安装的 Redis 可执行文件
### ---------------------------------------------------
echo "▶ 删除 Redis 可执行文件（/usr/local/bin）..."

BIN_LIST=(
    "/usr/local/bin/redis-server"
    "/usr/local/bin/redis-cli"
    "/usr/local/bin/redis-sentinel"
    "/usr/local/bin/redis-benchmark"
    "/usr/local/bin/redis-check-aof"
    "/usr/local/bin/redis-check-rdb"
)

for bin in "${BIN_LIST[@]}"; do
    if [ -f "$bin" ]; then
        echo "  - 删除 $bin"
        rm -f "$bin"
    fi
done


### ---------------------------------------------------
### 5. 删除 Redis 源码目录
### ---------------------------------------------------
SRC_DIR="/opt/redis/redis-7.0.15"
ROOT_DIR="/opt/redis"

if [ -d "$SRC_DIR" ]; then
    echo "▶ 检测到源码目录：$SRC_DIR"
    read -p "是否删除源码目录？(y/N): " confirm_src

    if [[ "$confirm_src" == "y" || "$confirm_src" == "Y" ]]; then
        echo "▶ 删除源码目录 ..."
        rm -rf "$SRC_DIR"
    else
        echo "✔ 保留源码目录"
    fi
else
    echo "✔ 源码目录不存在，跳过"
fi


### ---------------------------------------------------
### 6. 刷新 systemd
### ---------------------------------------------------
echo "▶ 刷新 systemd 配置 ..."
systemctl daemon-reload


### ---------------------------------------------------
### 7. 清理 Redis 运行日志
### ---------------------------------------------------
echo "▶ 清理系统日志 ..."
journalctl --rotate
journalctl --vacuum-time=1s


echo "==========================================="
echo "   ✔ Redis 7.0.15 已彻底卸载完毕"
echo "==========================================="
