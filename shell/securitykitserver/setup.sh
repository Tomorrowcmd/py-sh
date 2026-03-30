#!/bin/bash
# =================================================================
# 银河麒麟服务器 - 离线全自动部署脚本 (MariaDB + MinIO + + Redis + Java)
# =================================================================


# --- 1. 配置参数 ---
ENV_PROFILE="dev"                # 部署环境: dev 或 prod
MINIO_RPM="minio-0.0.20210116021944.x86_64.rpm"
JAR_NAME_WEB="securitykitserver-web-api-1.0.1.62.jar"
JAR_NAME_CLIENT="securitykitserver-client-api-1.0.1.59.jar"
REDIS_RPM="redis-7.0.15.tar.gz"
SQL_FILE="securitykitserver-全量2026-03-03.sql"       # 数据库初始化脚本
DB_NAME="securitykitserver_${ENV_PROFILE}" # 数据库名
INSTALL_BASE="/opt"
API_BIN_DIR="/usr/local/bin/securitykitserver"
MINIO_DATA_DIR="/opt/minio/data"

# 检查 root 权限, $EUID的意思是有效用户，如果等于0，就是root用户，≥1000通常分配给普通用户，和$UID一样
if [ "$EUID" -ne 0 ]; then
    echo "❌ 错误：请使用 root 权限运行此脚本"
    exit 1
fi

# --- 2. 离线环境依赖检查 ---
echo "▶ 检查必要组件..."
MISSING_TOOLS=()
for cmd in unzip zip rpm ip mysql; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_TOOLS+=("$cmd")
    fi
done

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "❌ 部署中止！服务器缺少必要组件: ${MISSING_TOOLS[*]}"
    echo "请手动安装组件（如 MariaDB 或 unzip/zip）后再运行。"
    exit 1
fi