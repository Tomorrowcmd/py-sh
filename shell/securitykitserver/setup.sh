#!/bin/bash
# =================================================================
# 银河麒麟服务器 - 离线全自动部署脚本 (MariaDB + MinIO + + Redis + Java)
# =================================================================


# --- 1. 配置参数 ---
ENV_PROFILE="dev"                # 部署环境: dev 或 prod
MINIO_RPM="minio-0.0.20210116021944.x86_64.rpm"
JAR_NAME_WEB="securitykitserver-web-api-1.0.1.62.jar"
JAR_NAME_CLIENT="securitykitserver-client-api-1.0.1.59.jar"
REDIS_TAR="redis-7.0.15.tar.gz"
REDIS_TAR_LOG="/tmp/redis_build.log"
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

echo "========= 开始全自动部署流程 ========="
sleep 2
# --- 3. MariaDB 配置与初始化 ---
echo "▶ 1/4 正在配置 MariaDB...请稍后..."
MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf"
# 0返回真，1返回假
if [ -f "$MARIADB_CONF" ]; then
    # 判断是否已配置 lower_case_table_names, 如果没有则返回1取反之后执行添加配置
    if ! grep -q "lower_case_table_names" "$MARIADB_CONF"; then
        # a表示匹配行下插入内容
        sed -i '/\[mysqld\]/a lower_case_table_names = 1' "$MARIADB_CONF"
        echo "✔ 已开启表名忽略大小写"
    fi
else
    echo "❌ 错误：未找到 $MARIADB_CONF"
    exit 1
fi

# 设置开机自启并立即启动 MariaDB 服务
systemctl enable mariadb --now
sleep 2s

echo "▶ 正在初始化数据库内容...请稍后..."
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
echo "▶ 2/4 正在安装 MinIO...请稍后..."
cd $INSTALL_BASE || exit 1
if [ -f "$MINIO_RPM" ]; then
#     强制安装这个 rpm 包不检查依赖已安装也覆盖
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
    sleep 1s
    
    echo "可通过systemctl status minio查看MinIO服务状态，或访问http://<服务器IP>:9010使用默认账号密码登录"
    echo "===========脚本种配置的默认账号: minioadmin 密码: minioadmin==========可修改"
else
    echo "❌ 缺失 MinIO RPM 包"
    exit 1
fi



# redis 安装 and 配置
echo "▶ 3/4 正在安装 Redis...请稍后..."
if [ -f "$INSTALL_BASE/$REDIS_TAR" ]; then
    echo "redis-7.0.15.tar.gz 包存在，开始安装..."
else
    echo "❌ 缺失 redis-7.0.15.tar.gz 包"
    exit 1
fi

echo "开始编译安装中，请稍后....中途请不要中断脚本执行，编译过程可能需要几分钟时间..."
touch "$REDIS_TAR_LOG"
# 修正点：确保目录创建逻辑正确
mkdir -p "$INSTALL_BASE/redis"
cp "$INSTALL_BASE/$REDIS_TAR" "$INSTALL_BASE/redis/"
cd "$INSTALL_BASE/redis" || exit 1

# 修正点：解压逻辑
tar -zxf "$REDIS_TAR"
cd "redis-7.0.15" || { echo "❌ 找不到解压后的 redis 目录"; exit 1; }

# 丢掉编译输出的内容, 0通常是标准输入（STDIN）, 1是标准输出（STDOUT）,2是标准错误输出（STDERR）
make >"$REDIS_TAR_LOG" 2>&1
make install >>"$REDIS_TAR_LOG" 2>&1

mkdir -p /etc/redis
cp redis.conf /etc/redis/
cd /etc/redis || exit 1

# 可根据实际调整是否开放远程连接和密码的修改
# sed -i 's/^bind 127.0.0.1 -::1/bind 0.0.0.0/' "/etc/redis/redis.conf" 
sed -i 's/^#\s*requirepass .*/requirepass 123456/' /etc/redis/redis.conf 

echo "✔ Redis 配置完成，正在设置系统服务... 请稍后..."
touch /etc/systemd/system/redis.service

cat > /etc/systemd/system/redis.service <<'EOF'
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/redis-server /etc/redis/redis.conf
ExecStop=/usr/local/bin/redis-cli shutdown
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sleep 2s

systemctl daemon-reload
systemctl enable redis --now

echo "redis 部署完毕, 可通过systemctl status redis查看服务状态，或使用redis-cli -a 123456 ping测试连接（返回PONG表示成功）"

# --- 5. 配置 SafetyDocument (修改 JAR 配置) ---
echo "▶ 4/4 正在配置 Java 服务包...请稍后..."
cd "$INSTALL_BASE" || exit 1
# 创建部署目录并复制 JAR 包
mkdir -p "$API_BIN_DIR/web"
mkdir -p "$API_BIN_DIR/client"

# 处理 JAR 包 and 配置文件临时目录
WEB_TEMP_CONF="$API_BIN_DIR/web/temp"
mkdir -p "$WEB_TEMP_CONF"

cp "$INSTALL_BASE/$JAR_NAME_WEB" "$API_BIN_DIR/web/"
cp "$INSTALL_BASE/$JAR_NAME_CLIENT" "$API_BIN_DIR/client/"
cd "$API_BIN_DIR/web" || exit 1

# 提取要修改的配置文件到临时目录
unzip -j "$JAR_NAME_WEB" "BOOT-INF/classes/application.yml" -d "$WEB_TEMP_CONF/"
unzip -j "$JAR_NAME_WEB" "BOOT-INF/classes/application-${ENV_PROFILE}.yml" -d "$WEB_TEMP_CONF/"
unzip -j "$JAR_NAME_WEB" "BOOT-INF/classes/systemconfig-${ENV_PROFILE}.yml" -d "$WEB_TEMP_CONF/"

# 获取本机ip
PHYSICAL_IP=$(ip addr | grep 'state UP' -A2 | grep 'inet ' | awk '{print $2}' | cut -f1 -d '/' | head -n1)

# 修改配置文件
sed -i 's/\r//g' "$WEB_TEMP_CONF"/*.yml
sed -i "s/active: .*/active: $ENV_PROFILE/g" "$WEB_TEMP_CONF/application.yml"
sed -i -E "s|(jdbc:mariadb://)[^:/ ]+(:[0-9]+/)[^? ]+|\1127.0.0.1\2${DB_NAME}|g" "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml"
sed -i "s#\(endpoint: http://\)[^:/ ]*#\1${PHYSICAL_IP}#g" "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml"

# 将 host: 127.0.0.1 替换为 host: 192.168.1.100 你指定需要的IP地址
# 限制范围：仅修改 redis: 块内的配置，防止误伤数据库密码
REDIS_PWD="123456" # 这里是你在 redis.conf 中设置的密码，确保一致
sed -i '/redis:/,/lettuce:/ s/host: .*/host: 127.0.0.1/' "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml"

# 修改端口 (强制为 6379)
if grep -A 5 "redis:" "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml" | grep -q "port:"; then
    sed -i '/redis:/,/lettuce:/ s/port: .*/port: 6379/' "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml"
else
    sed -i '/redis:/ s/host: .*/&\n    port: 6379/' "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml"
fi

# 匹配包含 password 的行，替换整行为新内容
# 1. 检查在 redis 范围内是否存在 password 行（兼容注释情况）
# 注意：这里修正了原代码末尾的单引号错误，并确保了缩进格式
if grep -A 10 "redis:" "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml" | grep -q "password:"; then
    # 逻辑：存在则替换。不论是 #password 还是 password，统一替换为标准缩进格式
    # 增加范围限制：仅在 redis 到 lettuce 之间修改
    sed -i '/redis:/,/lettuce:/ s/.*password:.*/    password: '"${REDIS_PWD}"'/' "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml"
else
    # 逻辑：不存在则追加。在 database 后面新起一行添加密码 (由于 database 值不固定，改为在 host 后插入更稳健)
    # 注意：在某些版本的 sed 中，a 命令后的缩进需要通过反斜杠或直接空格实现
    sed -i '/redis:/,/lettuce:/ s/host: .*/&\n    password: '"${REDIS_PWD}"'/' "$WEB_TEMP_CONF/application-${ENV_PROFILE}.yml"
fi
# >>> 这是你要添加的那一行 <<<
sed -i "s|C:/TempUploadFileDirectory/|/root/TempUploadFileDirectory/|g" "$WEB_TEMP_CONF/systemconfig-${ENV_PROFILE}.yml"


# 压缩回 JAR 包
cd "$WEB_TEMP_CONF" || exit 1
mkdir -p BOOT-INF/classes
mv *.yml BOOT-INF/classes/
zip -u "$API_BIN_DIR/web/$JAR_NAME_WEB" BOOT-INF/classes/*
rm -rf "$WEB_TEMP_CONF"

# 修改client
# 处理 JAR 包 and 配置文件临时目录
CLIENT_TEMP_CONF="$API_BIN_DIR/client/temp"
mkdir -p "$CLIENT_TEMP_CONF"
cd "$API_BIN_DIR/client" || exit 1

# 提取要修改的配置文件到临时目录
# 修正点：将变量名由 $CLIENT_NAME 统一为 $JAR_NAME_CLIENT，否则 unzip 找不到文件
unzip -j "$JAR_NAME_CLIENT" "BOOT-INF/classes/application.yml" -d "$CLIENT_TEMP_CONF/"
unzip -j "$JAR_NAME_CLIENT" "BOOT-INF/classes/application-${ENV_PROFILE}.yml" -d "$CLIENT_TEMP_CONF/"
unzip -j "$JAR_NAME_CLIENT" "BOOT-INF/classes/systemconfig-${ENV_PROFILE}.yml" -d "$CLIENT_TEMP_CONF/"


# 修改配置文件
sed -i 's/\r//g' "$CLIENT_TEMP_CONF"/*.yml
sed -i "s/active: .*/active: $ENV_PROFILE/g" "$CLIENT_TEMP_CONF/application.yml"
sed -i -E "s|(jdbc:mariadb://)[^:/ ]+(:[0-9]+/)[^? ]+|\1127.0.0.1\2${DB_NAME}|g" "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml"
sed -i "s#\(endpoint: http://\)[^:/ ]*#\1${PHYSICAL_IP}#g" "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml"

# 将 host: 127.0.0.1 替换为 host: 192.168.1.100 你指定需要的IP地址
# 修正点：原代码在处理 Client 时路径误写成了 $WEB_TEMP_CONF，已更正为 $CLIENT_TEMP_CONF
# 增加范围限制：仅修改 redis 块内容
sed -i '/redis:/,/lettuce:/ s/host: .*/host: 127.0.0.1/' "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml"

# 修改端口 (强制为 6379)
if grep -A 5 "redis:" "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml" | grep -q "port:"; then
    sed -i '/redis:/,/lettuce:/ s/port: .*/port: 6379/' "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml"
else
    sed -i '/redis:/ s/host: .*/&\n    port: 6379/' "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml"
fi

# 匹配包含 password 的行，替换整行为新内容
# 1. 检查在 redis 范围内是否存在 password 行（兼容注释情况）
# 注意：这里修正了原代码末尾的单引号错误，并确保了缩进格式
if grep -A 10 "redis:" "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml" | grep -q "password:"; then
    # 逻辑：存在则替换。不论是 #password 还是 password，统一替换为标准缩进格式
    # 增加范围限制：仅在 redis 到 lettuce 之间修改
    sed -i '/redis:/,/lettuce:/ s/.*password:.*/    password: '"${REDIS_PWD}"'/' "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml"
else
    # 逻辑：不存在则追加。在 host 后面新起一行添加密码
    # 注意：在某些版本的 sed 中，a 命令后的缩进需要通过反斜杠或直接空格实现
    sed -i '/redis:/,/lettuce:/ s/host: .*/&\n    password: '"${REDIS_PWD}"'/' "$CLIENT_TEMP_CONF/application-${ENV_PROFILE}.yml"
fi
# >>> 这是你要添加的那一行 <<<
sed -i "s|C:/TempUploadFileDirectory/|/root/TempUploadFileDirectory/|g" "$CLIENT_TEMP_CONF/systemconfig-${ENV_PROFILE}.yml"

# 压缩回 JAR 包
cd "$CLIENT_TEMP_CONF" || exit 1
mkdir -p BOOT-INF/classes
mv *.yml BOOT-INF/classes/
# 修正点：将变量名由 $CLIENT_NAME 统一为 $JAR_NAME_CLIENT
zip -u "$API_BIN_DIR/client/$JAR_NAME_CLIENT" BOOT-INF/classes/*
rm -rf "$CLIENT_TEMP_CONF"

echo "✔ Java 配置修改完成"




# --- 6. 创建 API systemd 服务 ---
# =============================================
# 1. 配置区
# =============================================
SYSTEMD_DIR="/etc/systemd/system"
RUN_USER="root"
JAVA_PATH="/usr/bin/java"

# 定义服务名与 JAR 包的映射
# 优化：如果 jar 在子目录下，请包含子目录路径
# 修正点：映射变量名已同步
declare -A SERVICES=(
    ["securitykitserver-web-api"]="web/${JAR_NAME_WEB}"
    ["securitykitserver-client-api"]="client/${JAR_NAME_CLIENT}"
)

# =============================================
# 2. 生成函数
# =============================================
create_service() {
    local name="$1"
    local jar_path="$2"
    local file="${SYSTEMD_DIR}/${name}.service"
    
    # 提取子目录路径和文件名
    # 假设 jar_path 是 "web-api/web-api.jar"
    # full_work_dir 会变成 "/usr/local/bin/tongyiyunwei/web-api"
    # sub_dir_name 会变成 "web-api"
    # jar_name 会变成 "web-api.jar"
    # dirname 路径 → 输出目录
    # basename 路径 → 输出文件名
    local sub_dir=$(dirname "$jar_path")
    local jar_name=$(basename "$jar_path")
    local full_work_dir="${API_BIN_DIR}/${sub_dir}"

    echo ">> 正在生成: ${name} (目录: ${sub_dir})"

    cat > "$file" <<EOF
[Unit]
Description=${name} Service
After=network.target

[Service]
User=${RUN_USER}
# 优化点：WorkingDirectory 现在指向 jar 包所在的精确目录
WorkingDirectory=${full_work_dir}
ExecStart=${JAVA_PATH} -jar ${full_work_dir}/${jar_name}
Restart=always
RestartSec=10s
SyslogIdentifier=${name}

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "$file"
}

# =============================================
# 3. 执行逻辑
# =============================================

# 权限与目录检查
[[ $EUID -ne 0 ]] && echo "错误: 请以 root 权限运行。" && exit 1
[[ ! -d "$API_BIN_DIR" ]] && echo "警告: 目录 $API_BIN_DIR 不存在！"

# 批量生成，提取关联数组所有的“服务名”（键），并存入一个普通数组。
# 开头的感叹号 ! 是关键，它告诉 Bash：“我不要数组里的值（jar包名），我要所有的键名（服务名）”。
for name in "${!SERVICES[@]}"; do
    create_service "$name" "${SERVICES[$name]}"
done

# 重载系统配置
systemctl daemon-reload

# 结果展示
# 这行代码的作用是：提取关联数组所有的“服务名”（键），并存入一个普通数组。
# !SERVICES[@]：开头的感叹号 ! 是关键，它告诉 Bash：“我不要数组里的值（jar包名），我要所有的键名（服务名）”。
keys=("${!SERVICES[@]}")
# 技巧：如果数组不为空，则取第一个元素作为示例
# 这行代码的作用是：获取第一个服务名；如果数组是空的，就给一个默认值。
example_srv1=${keys[0]:-"service-name"}
example_srv2=${keys[1]:-"service-name"}

echo "------------------------------------------------"
echo "✅ 所有服务配置已生成！并已重载系统服务！"
echo "当前服务列表: ${keys[*]}"
echo "------------------------------------------------"
echo "常用命令参考："
echo "启动所有:  for s in ${keys[*]}; do systemctl start \$s; done"
echo "查看日志:  journalctl -u $example_srv1 -f"
echo "查看日志:  journalctl -u $example_srv2 -f"
echo "------------------------------------------------"