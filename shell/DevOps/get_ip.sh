#!/bin/bash

# 获取当前时间
DATE=$(data '+%Y-%m-%d %H:%M:%S')

# 定义输出文件路径
OUTPUT_FILE="/opt/ip_addresses.txt"

IP=$(hostname -I | awk '{print $1}')

if [ -z "$IP" ]; then
  echo "[$DATE] 未能获取到IP地址。" >> "$OUTPUT_FILE"
else
  echo "[$DATE] 当前服务器的IP地址是: $IP" >> "$OUTPUT_FILE"
fi