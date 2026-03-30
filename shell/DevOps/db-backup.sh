#!/bin/bash

# mariaDB账号密码
USER="root"
PASS="root"

#数据库名称
DBS="hostalarmreceive_dev"

# 备份存放目录
BACKUP_DIR="/opt/db_backups"

# 生成文件名
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR


# 开始备份, 如果本地连接数据库没有密码就不要加-p:  mysqldump -u$USER -p$PASS $db > $BACKUP_DIR/${db}_${DATE}.sql
for db in $DBS
do
    # mysqldump -u$USER $db > $BACKUP_DIR/${db}_${DATE}.sql
    mysqldump -u$USER -p$PASS $db > $BACKUP_DIR/${db}_${DATE}.sql
done

# 可选：删除90天前的旧备份
# find $BACKUP_DIR -type f -mtime +90 -delete


# 创建执行任务
# crontab -e
# 加入
# 0 2 1 * * /opt/db-backup.sh >/var/log/db-backup.log 2>&1

# 每月 1 日

# 凌晨 2:00

# 自动执行备份脚本

# 日志记录到 /var/log/db-backup.log

#| 字段位置 | 含义         | 取值范围             |
#| ---- | ---------- | ---------------- |
#| 1    | 分钟         | 0–59             |
#| 2    | 小时         | 0–23             |
#| 3    | 日（一个月的第几天） | 1–31             |
#| 4    | 月份         | 1–12             |
#| 5    | 星期几        | 0–7（0 和 7 都是星期日） |

# 建一个测试每分钟执行一次
# * * * * * /opt/db-backup.sh >/var/log/db-backup.log 2>&1


