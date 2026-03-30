#!/bin/bash

# 设置错误处理,出错时不往下执行
# set -ex
set -e


apt update
apt upgrade -y
SERVUCE_FILE="/etc/systemd/system/minio.service"

dpkg -i /opt/minio_20240606093642.0.0_amd64.deb

mkdir -p /data/minio
useradd -r -s /sbin/nologin minio
chown -R minio:minio /data/minio


cat > "$SERVUCE_FILE" <<EOF
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio
Group=minio
ExecStart=/usr/local/bin/minio server /data/minio --console-address ":9001"
Restart=always
Environment="MINIO_ROOT_USER=minioadmin"
Environment="MINIO_ROOT_PASSWORD=minioadmin"

[Install]
WantedBy=multi-user.target

EOF

systemctl daemon-reload

