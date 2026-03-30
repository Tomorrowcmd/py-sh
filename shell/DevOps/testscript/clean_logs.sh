#!/bin/bash

LOG_DIR="/data/app/my-project/logs"
KEEP_DAYS=7   # 保留最近7天的日志


echo "开始清理任务: $(date)"

# 1. 查找并删除 7 天前的旧日志（以 .log 结尾的文件）
# -mtime +7 表示修改时间在 7 天以前, mtime = 文件内容修改时间， -exec rm -rf {} \; 表示对找到的文件执行 rm -rf 命令，{} = 当前找到的文件
find "$LOG_DIR" -name "*.log.*" -mtime +$KEEP_DAYS -exec rm -rf {} \;

# 2. (进阶) 将超过 3 天且未压缩的日志进行压缩，节省空间， -not -name "*.gz" 表示不压缩已压缩的文件
find "$LOG_DIR" -name "*.log" -mtime +3 -not -name "*.gz" -exec gzip {} \;

echo "清理完成。"