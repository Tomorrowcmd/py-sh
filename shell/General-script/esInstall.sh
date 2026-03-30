#!/bin/bash

set -e  # 出错自动退出

# 进入 /opt 目录
cd /opt

# Elasticsearch tar 包名称
# elasticsearch_tar="elasticsearch-7.15.2-linux-aarch64.tar.gz"
elasticsearch_tar="elasticsearch-7.15.2-linux-x86_64.tar.gz"

# 解压 Elasticsearch 压缩包
tar -zxvf ${elasticsearch_tar}

# 创建 Elasticsearch 用户
useradd elasticsearch
chown -R elasticsearch:elasticsearch /opt/elasticsearch-7.15.2

# 创建数据目录与日志目录
mkdir -p /opt/elasticsearch-7.15.2/data
mkdir -p /opt/elasticsearch-7.15.2/logs
chown -R elasticsearch:elasticsearch /opt/elasticsearch-7.15.2    

# 配置文件路径
elasticsearch_config_dir="/opt/elasticsearch-7.15.2/config"
elasticsearch_yml="${elasticsearch_config_dir}/elasticsearch.yml"

echo "正在修改 Elasticsearch 配置文件: ${elasticsearch_yml}"

# 定义一个辅助函数：存在则修改，不存在则追加
set_config() {
    local key="$1"
    local value="$2"
    # ^ 代表从行首开始匹配 -q代表不输出，只看有没有匹配
    if grep -q "^${key}:" "$elasticsearch_yml"; then
      # 匹配到了就开始进行替换，-i表示原地修改，s表示替换，^从行首开始后跟要替换的新值
        sed -i "s|^${key}:.*|${key}: ${value}|" "$elasticsearch_yml"
    else
      # 如果不存在，就直接追加到文件末尾
        echo "${key}: ${value}" >> "$elasticsearch_yml"
    fi
}

# 修改配置项
set_config "http.cors.enabled" "true"
set_config "network.host" "0.0.0.0"
set_config "http.port" "9200"
# 集群通信节点的地址，如果还有其他节点，可以用逗号分隔添加，不能写本地IP
set_config "transport.host" "localhost"
set_config "transport.tcp.port" "9300"
set_config "http.cors.allow-origin" "\"*\""
set_config "http.cors.allow-credentials" "true"
set_config "http.cors.allow-headers" "\"Content-Type,Accept,Authorization,x-requested-with\""
set_config "path.data" "/opt/elasticsearch-7.15.2/data"
set_config "path.logs" "/opt/elasticsearch-7.15.2/logs"

# 设置内存限制
echo "elasticsearch soft memlock unlimited" >> /etc/security/limits.conf
echo "elasticsearch hard memlock unlimited" >> /etc/security/limits.conf

# 创建 systemd 服务文件
elasticsearch_service="/etc/systemd/system/elasticsearch.service"

cat > "$elasticsearch_service" <<EOF
[Unit]
Description=Elasticsearch
After=network.target

[Service]
Type=simple
User=elasticsearch
ExecStart=/opt/elasticsearch-7.15.2/bin/elasticsearch
Restart=on-failure
LimitMEMLOCK=infinity
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启用自启动
systemctl daemon-reload
systemctl enable elasticsearch.service

# 输出部署完成信息
echo "部署完毕, 请启动 Elasticsearch: systemctl start elasticsearch"




# Elasticsearch 默认会监听 9200 端口，你可以使用 curl 命令进行简单的 HTTP 请求来测试 Elasticsearch 是否正常响应。
# curl -X GET "localhost:9200/"

