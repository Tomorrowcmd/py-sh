#!/bin/bash

set -e  # 出错自动退出

cd /opt

mkdir redis

redis_tar="redis-7.0.15.tar.gz"
LOG="/tmp/redis_build.log"

echo "开始编译安装中，请稍后...."

touch /tmp/redis_build.log

mv ${redis_tar} /opt/redis

cd /opt/redis

tar -xf ${redis_tar}

cd "redis-7.0.15"


# 丢掉编译输出的内容, 0通常是标准输入（STDIN）, 1是标准输出（STDOUT）,2是标准错误输出（STDERR）
make >"$LOG" 2>&1

make install > /dev/null

pwd

mkdir /etc/redis

cp redis.conf /etc/redis

cd /etc/redis

# sed -i 's/^bind 127.0.0.1 -::1/bind 0.0.0.0/' "/etc/redis/redis.conf" 
sed -i 's/^#\s*requirepass .*/requirepass 123456/' /etc/redis/redis.conf 

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

systemctl daemon-reload
systemctl enable redis --now

echo "redis 部署完毕"




