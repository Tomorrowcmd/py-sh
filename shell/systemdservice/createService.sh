#!/bin/bash

# =============================================
# 1. 配置区
# =============================================
SERVICE_DIR="/usr/local/bin/tongyiyunwei"
SYSTEMD_DIR="/etc/systemd/system"
RUN_USER="root"
JAVA_PATH="/usr/bin/java"

# 定义服务名与 JAR 包的映射
# 优化：如果 jar 在子目录下，请包含子目录路径
declare -A SERVICES=(
    ["web-api"]="web-api/web-api.jar"
    ["rule-engine"]="rule-engine/rule-engine-1.0-SNAPSHOT.jar"
    ["logdata-handle"]="logdata-handle/logdata-handle.jar"
    ["data-aggregation"]="data-aggregation/data-aggregation.jar"
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
    local sub_dir=$(dirname "$jar_path")
    local jar_name=$(basename "$jar_path")
    local full_work_dir="${SERVICE_DIR}/${sub_dir}"

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
[[ ! -d "$SERVICE_DIR" ]] && echo "警告: 目录 $SERVICE_DIR 不存在！"

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
example_srv=${keys[0]:-"service-name"}

echo "------------------------------------------------"
echo "✅ 所有服务配置已生成！并已重载系统服务！"
echo "当前服务列表: ${keys[*]}"
echo "------------------------------------------------"
echo "常用命令参考："
echo "启动所有:  for s in ${keys[*]}; do systemctl start \$s; done"
echo "查看日志:  journalctl -u $example_srv -f"
echo "------------------------------------------------"