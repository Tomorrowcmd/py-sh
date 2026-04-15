#!/bin/bash
# =================================================================
# 银河麒麟服务器 - 离线全自动部署脚本 (MariaDB + MinIO + Java)
# =================================================================

# --- 1. 配置参数 ---
ENV_PROFILE="dev"                # 部署环境: dev 或 prod
MINIO_RPM="minio-0.0.20210116021944.x86_64.rpm"
JAR_NAME="safetydocument-api-5.4.3.108.jar"
SQL_FILE="safetydocument-260210全量脚本.sql"       # 数据库初始化脚本
DB_NAME="safetydocument_${ENV_PROFILE}" # 数据库名
INSTALL_BASE="/opt"
API_BIN_DIR="/usr/local/bin/safetydocument"
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

echo "========= 开始全自动部署流程 ========="
sleep 2
# --- 3. MariaDB 配置与初始化 ---
echo "▶ 1/4 正在配置 MariaDB...请稍后..."
MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf"
if [ -f "$MARIADB_CONF" ]; then
    if ! grep -q "lower_case_table_names" "$MARIADB_CONF"; then
        sed -i '/\[mysqld\]/a lower_case_table_names = 1' "$MARIADB_CONF"
        echo "✔ 已开启表名忽略大小写"
    fi
else
    echo "❌ 错误：未找到 $MARIADB_CONF"
    exit 1
fi
# 设置开机自启并立即启动 MariaDB 服务
systemctl enable mariadb --now

echo "▶ 正在初始化数据库内容..."
  if [ ! -f "$INSTALL_BASE/$SQL_FILE" ]; then
    echo "⚠️ 警告：未找到 SQL 脚本 $SQL_FILE，跳过导入"
else
    # 自动执行密码修改与建库导入
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';
ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY 'root';
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE ${DB_NAME};
SOURCE ${INSTALL_BASE}/${SQL_FILE};
FLUSH PRIVILEGES;
EOF
    echo "✔ 数据库 $DB_NAME 初始化完成"
fi

# --- 4. 安装 MinIO (解决 Service 不存在报错) ---
echo "▶ 2/4 正在安装 MinIO..."
cd $INSTALL_BASE || exit 1
if [ -f "$MINIO_RPM" ]; then
#    强制安装这个 rpm 包不检查依赖已安装也覆盖
    rpm -ivh "$MINIO_RPM" --force --nodeps > /dev/null 2>&1
    mkdir -p "$MINIO_DATA_DIR"

    # 生成环境配置文件
    cat > /etc/default/minio <<EOF
MINIO_VOLUMES="$MINIO_DATA_DIR"
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_OPTS="--address :9010"
EOF

    # 生成 Service 文件
    cat > /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO Object Storage Server
After=network.target

[Service]
User=root
Group=root
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    # 必须先 daemon-reload 才能 enable
    systemctl daemon-reload
    systemctl enable minio --now
    echo "✔ MinIO 启动成功 (端口 9010)"
else
    echo "❌ 缺失 MinIO RPM 包"
    exit 1
fi

# --- 5. 配置 SafetyDocument (修改 JAR 配置) ---
echo "▶ 3/4 正在配置 Java 服务包..."
cd $INSTALL_BASE || exit 1
mkdir -p "$API_BIN_DIR/temp"
cp "$JAR_NAME" "$API_BIN_DIR/"
cd "$API_BIN_DIR" || exit 1

# 提取要修改的配置文件到临时目录
TEMP_CONF="./temp"
unzip -j "$JAR_NAME" "BOOT-INF/classes/application.yml" -d "$TEMP_CONF/"
unzip -j "$JAR_NAME" "BOOT-INF/classes/application-${ENV_PROFILE}.yml" -d "$TEMP_CONF/"
unzip -j "$JAR_NAME" "BOOT-INF/classes/systemconfig-${ENV_PROFILE}.yml" -d "$TEMP_CONF/"

# 获取本机ip
PHYSICAL_IP=$(ip addr | grep 'state UP' -A2 | grep 'inet ' | awk '{print $2}' | cut -f1 -d '/' | head -n1)

# 修改配置文件
sed -i 's/\r//g' "$TEMP_CONF"/*.yml
sed -i "s/active: .*/active: $ENV_PROFILE/g" "$TEMP_CONF/application.yml"
sed -i -E "s|(jdbc:mysql://)[^:/ ]+(:[0-9]+/)[^? ]+|\1127.0.0.1\2${DB_NAME}|g" "$TEMP_CONF/application-${ENV_PROFILE}.yml"
sed -i "s#\(endpoint: http://\)[^:/ ]*#\1${PHYSICAL_IP}#g" "$TEMP_CONF/application-${ENV_PROFILE}.yml"

# >>> 这是你要添加的那一行 <<<
sed -i "s|C:/TempUploadFileDirectory/|/root/TempUploadFileDirectory/|g" "$TEMP_CONF/systemconfig-${ENV_PROFILE}.yml"

# 压缩回 JAR 包
cd "$TEMP_CONF" || exit 1
mkdir -p BOOT-INF/classes
mv *.yml BOOT-INF/classes/
zip -u "$API_BIN_DIR/$JAR_NAME" BOOT-INF/classes/*
cd "$API_BIN_DIR" || exit 1
rm -rf "$TEMP_CONF"
echo "✔ Java 配置修改完成"

# --- 6. 创建 API systemd 服务 ---
echo "▶ 4/4 正在创建 API 自启动服务..."
cat > /etc/systemd/system/safetydocument-api.service <<EOF
[Unit]
Description=safetydocument-api Service
After=network.target mariadb.service minio.service

[Service]
User=root
WorkingDirectory=${API_BIN_DIR}
ExecStart=/usr/bin/java -jar ${API_BIN_DIR}/${JAR_NAME}
Restart=always
SyslogIdentifier=safetydocument-api

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable safetydocument-api --now

echo "========= 部署总结 =========="
echo "1. 数据库: $DB_NAME (root/root)"
echo "2. MinIO: http://${PHYSICAL_IP}:9010"
echo "3. Java服务状态: systemctl status safetydocument-api"
echo "============================"

# 清理安装包
rm -f "$INSTALL_BASE/$MINIO_RPM"