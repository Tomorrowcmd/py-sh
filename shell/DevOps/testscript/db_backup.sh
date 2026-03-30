#!/bin/bash

#############################
# 数据库备份脚本
# Author: admin
#############################

# ==========基本配置===========
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_USER="root"
DB_PASS="root"
DB_NAME="testdb"

BACKUP_DIR="/data/db_backup"
LOG_FILE="/data/db_backup/backup.log"
KEEP_DAYS=7

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${DB_NAME}_${DATE}}.sql"

# ===== 创建备份目录 =====
[ ! -d "$BACKUP_DIR" ] && mkdir -p "$BACKUP_DIR"

echo "=========== $(date '+%F %T') 开始备份 =============" >> $LOG_FILE

# =========== 开始备份 =============
mysqldump -h$DB_HOST -P$DB_ROOT -u$%DB_USER -p$DB_PASS $DB_NAME > $BACKUP_DIR/$BACKUP_FILE 2>> $LOG_FILE

# ========== 判断是否成功 ============
# $? 表示上一个命令执行的状态
if [ $? -eq 0 ]; then
  echo "备份成功:$BACKUP_FILE" >> $LOG_FILE
else
  echo "备份失败:$BACKUP_FILE" >> $LOG_FILE
  exit 1
fi

# ========== 压缩备份文件 ==========
gzip $BACKUP_DIR/$BACKUP_FILE

echo "压缩完成:${BACKUP_FILE}.gz" >> $LOG_FILE

# ===========================
# 清理过期文件（超过7天）
# ===========================

echo "开始清理 $KEEP_DAYS 天前的备份文件..." >> $LOG_FILE

# 找到过期文件
OLD_FILES=$(find $BACKUP_DIR -name "*.gz" -mtime +$KEEP_DAYS)

if [ -n "$OLD_FILES" ]; then
  echo "$OLD_FILES" | while read file
  do
    echo "删除过期文件: $file" >> $LOG_FILE
    rm -f "$file"
  done
else
  echo "没有需要删除的文件" >> $LOG_FILE
fi



# ===========================
# 使用三剑客处理日志
# ===========================

echo "=========== 日志分析 ===============" >> $LOG_FILE

# grep 统计成功次数
SUCCESS_COUNT=$(grep "备份成功" $LOG_FILE | wc -l)
echo "历史成功次数: $SUCCESS_COUNT" >> $LOG_FILE

# awk 统计每一天的备份次数
echo "每日统计: " >> $LOG_FILE
grep "开始备份" $LOG_FILE | awk '{print $1}' | sort | uniq -c >> $LOG_FILE

# sed 替换日志中的密码信息(防止泄露)
sed -i "s/$DB_PASS/******/g" $LOG_FILE

echo "=========== $(date '+%F %T') 备份结束 ============" >> $LOG_FILE



