#!/bin/bash
set -e  # 出错自动退出
### ----------------------------
### 1. 安装 MinIO RPM
### ----------------------------
cd /opt

MINIO_RPM="minio-0.0.20210116021944.x86_64.rpm"

if [ ! -f "$MINIO_RPM" ]; then
  echo "❌ 找不到 RPM 包: $MINIO_RPM"
  exit 1
fi

echo "▶ 安装 MinIO RPM ..."
rpm -ivh $MINIO_RPM > /dev/null 2>&1


### ----------------------------
### 2. 创建数据目录
### ----------------------------
echo "▶ 创建 MinIO 数据目录 ..."

mkdir -p /opt/minio/data


### ----------------------------
### 3. 创建 MinIO 环境变量文件
### ----------------------------
echo "▶ 写入环境变量 /etc/default/minio ..."

cat > /etc/default/minio <<EOF
# MinIO 数据存放路径（旧版只能写 MINIO_VOLUMES）
MINIO_VOLUMES=/opt/minio/data

# 管理后台账号密码（旧版本必须使用以下两个变量）
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin

# 可选端口
MINIO_OPTS="--address :9010"
EOF


### ----------------------------
### 4. 创建 systemd 服务文件
### ----------------------------
echo "▶ 创建 systemd 服务文件 /etc/systemd/system/minio.service ..."

cat > /etc/systemd/system/minio.service <<EOF
[Unit]
Description=MinIO Object Storage Server
After=network.target

[Service]
User=root
Group=root
EnvironmentFile=/etc/default/minio

# 旧版 MinIO 不支持 console-address，不支持 config-dir
ExecStart=/usr/local/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES

Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


### ----------------------------
### 5. 重载 systemd & 启动服务
### ----------------------------
systemctl daemon-reload
systemctl enable minio
systemctl start minio

echo "✔ MinIO 已启动"

### ----------------------------
### 6. 打印访问信息
### ----------------------------
echo "-------------------------------------------"
echo " MinIO 安装完成（旧版 2021）"
echo " 管理界面（MinIO Browser）："
echo "    http://<服务器IP>:9010"
echo ""
echo " 默认账号：minioadmin"
echo " 默认密码：minioadmin"
echo " 数据目录：/opt/minio/data"
echo "-------------------------------------------"
