#!/bin/bash
# 监控服务器 CPU、内存、磁盘、超过阈值则打印警告
THRESHOLD=80
LOG_FILE="/var/log/system_monitor.log"

echo "---- 检查时间: $(date '+%Y-%m-%d %H:%M:%S') ----" >> $LOG_FILE

# 1、检查磁盘(取根目录使用率数字)
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt "$THRESHOLD" ]; then
  echo "[警告] 磁盘空间不足"
fi

# 检查内存(计算百分比)
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

if [ "$MEM_PERCENT" -gt "$THRESHOLD" ]; then
  echo "[警告] 内存使用率过高: ${MEM_PERCENT}%" >> $LOG_FILE
else
  echo "[正常] 内存使用: ${MEM_PERCENT}%" >> $LOG_FILE
fi

# 提示用户检查日志
echo "请检查日志文件: $LOG_FILE"


