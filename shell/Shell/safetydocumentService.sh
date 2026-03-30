#!/bin/bash

# =============================================
# Shell模板：生成Java服务的systemd service文件
# =============================================

# 基础路径：所有服务的工作目录
SERVICE_DIR="/usr/local/bin/safetydocument"

# systemd service 存放目录（一般不需要改）
SYSTEMD_DIR="/etc/systemd/system"


# 函数：生成 service 文件
# 参数：
#   $1 = 服务名 (用于service名称 & SyslogIdentifier & Description)
#   $2 = jar文件名
create_service() {
    local name="$1"
    local jar="$2"
    local service_file="${SYSTEMD_DIR}/${name}.service"

    echo "生成 service: $service_file"

    cat > "$service_file" <<EOF
[Unit]
#  服务描述
Description=${name} Service
# 指定服务启动顺序，在 network.target（网络服务）之后再启动。
After=network.target

[Service]
User=root
# 服务运行的当前工作目录
WorkingDirectory=${SERVICE_DIR}
# 启动服务的命令
ExecStart=/usr/bin/java -jar ${SERVICE_DIR}/${jar}
# 无论退出状态如何，总会重启。
Restart=always
# 指定系统日志（journal）中的标识符
SyslogIdentifier=${name}

[Install]
# 用于定义服务在哪个 target 下被自动启动
WantedBy=multi-user.target
EOF

    echo "生成完成: $service_file"
}

# =============================================
# 示例：定义服务名和对应的jar文件
# =============================================
create_service "safetydocument-api" "safetydocument-api-5.4.3.108.jar"
create_service "safetydocument-device" "safetydocument-device-api-5.4.3.126.jar"

# 重载 systemd 配置
systemctl daemon-reload


echo "全部 service 文件生成完成，可使用 systemctl enable/start 启动服务"