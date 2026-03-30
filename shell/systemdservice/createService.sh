#!/bin/bash

# 基础路径
SERVICE_DIR="/usr/local/bin/tongyiyunwei"
SYSTEMD_DIR="/etc/systemd/system"
RUN_USER="root" 

# 函数：生成 service 文件
create_service() {
    local name="$1"
    local jar="$2"
    local service_file="${SYSTEMD_DIR}/${name}.service"

    echo "正在生成 service: $service_file"

    cat > "$service_file" <<EOF
[Unit]
Description=${name} Service
After=network.target

[Service]
User=${RUN_USER}
WorkingDirectory=${SERVICE_DIR}
# 最简启动命令
ExecStart=/usr/bin/java -jar ${SERVICE_DIR}/${jar}

# 基础防护配置
Restart=always
RestartSec=10s
SuccessExitStatus=143
SyslogIdentifier=${name}

[Install]
WantedBy=multi-user.target
EOF

    echo "生成完成: $service_file"
}

# =============================================
# 定义服务名和对应的jar文件，根据需求进行修改
# =============================================
create_service "web-api" "web-api.jar"
create_service "rule-engine" "rule-engine-1.0-SNAPSHOT.jar"
create_service "logdata-handle" "logdata-handle.jar"
create_service "data-aggregation" "data-aggregation.jar"

# 重载配置
systemctl daemon-reload

echo "------------------------------------------------"
echo "所有服务已处理完毕！"
echo "常用操作命令："
echo "启动：systemctl start web-api"
echo "查看状态：systemctl status web-api"
echo "查看日志：journalctl -u web-api -f"