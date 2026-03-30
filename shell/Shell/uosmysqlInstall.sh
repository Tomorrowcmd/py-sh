#!/bin/bash

# 设置错误处理,出错时不往下执行
# set -ex
set -e

#安装之前先删除旧版本残留
# echo ">>> 清理旧版本 MySQL/mariadb残留"
# dnf remove -y mariadb* perl-DBD-MySQL python2-mysqlclient qt5-qtbase-mysql || true
# yum remove -y mariadb mariadb-server mariadb-common mariadb-libs || true

# mariadb_list=$(rpm -qa | grep -i mariadb || true) 
# if [ -n "$mariadb_list" ]; then
#     yum remove -y $mariadb_list || true
# else
#     echo "未检测到mariadb包, 无需卸载"
# fi

# # yum remove -y $(rpm -qa | grep -i mariadb)

# rm -rf /var/lib/mysql || true

# mariadb_file=$(rpm -qa | grep -i mariadb || true)


# if [ -z "$mariadb_file" ]; then
#     echo "卸载完成"
# else
#     echo "还有残留文件"
# fi

GROUP_NAMES="mysql"
USER_NAMES="mysql"
mysql_tar="/opt/mysql-8.0.43-linux-glibc2.28-x86_64.tar.xz"
MYSQL_BASE="/usr/local/mysql"
NEW_PASSWORD="root"  # 你可以根据需要修改默认新密码

[ ! -f "$mysql_tar" ] && { echo "$mysql_tar 不存在"; exit 1;}

cd /opt
tar -xvf ${mysql_tar}

cd /opt/mysql-8.0.43-linux-glibc2.28-x86_64

# 创建用户组和用户
if ! getent group $GROUP_NAMES > /dev/null 2>&1; then
    groupadd $GROUP_NAMES
    echo "用户组 $GROUP_NAMES 创建成功"
fi

if ! id "$USER_NAMES" > /dev/null 2>&1; then
    useradd -m -g "$GROUP_NAMES" "$USER_NAMES"
    echo "用户 $USER_NAMES 创建成功"
fi

echo "已创建用户和组"

# 创建存放目录
mkdir -p /usr/local/mysql
mv /opt/mysql-8.0.43-linux-glibc2.28-x86_64/* /usr/local/mysql/
cd /usr/local/mysql
mkdir -p /usr/local/mysql/data
chown -R mysql:mysql /usr/local/mysql

# 创建配置文件
MYCNF_PATH="/etc/my.cnf"
cat > $MYCNF_PATH <<EOF
[client]
port=3306
socket=/usr/local/mysql/mysql.sock

[mysqld]
basedir=/usr/local/mysql
datadir=/usr/local/mysql/data
socket=/usr/local/mysql/mysql.sock
port=3306
user=mysql
symbolic-links=0
character-set-server=utf8mb4
default_authentication_plugin=mysql_native_password
lower_case_table_names=1
bind-address=0.0.0.0
log-error=/usr/local/mysql/data/mysqld.log
EOF

echo ">>> 初始化Mysql...."
# 删除数据目录中的文件（如果目录不为空）
rm -rf /usr/local/mysql/data/*

# 初始化 MySQL
# /usr/local/mysql/bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data

OUTPUT=$(/usr/local/mysql/bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data 2>&1) || {
    echo "初始化失败"
    echo "$OUTPUT"
    exit 1
}

# 从输出中抓取临时密码
LOG_FILE="/usr/local/mysql/data/mysqld.log"
# TEMP_PASS=$(grep -oP 'A temporary password is generated for root@localhost: \K\S+' $LOG_FILE)
TEMP_PASS=$(grep -oP 'A temporary password is generated for root@localhost: \K\S+' "$LOG_FILE" || true)
if [ -z "$TEMP_PASS" ]; then
    echo "临时密码未找到, 请检查日志：$LOG_FILE"
    exit 1
fi
echo "临时密码是：$TEMP_PASS"


# 配置自启动服务
cat > /etc/systemd/system/mysqld.service <<'EOF'
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf --user=mysql
User=mysql
Group=mysql
LimitNOFILE=5000
Restart=on-failure
TimeoutSec=600

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# 启动 MySQL
systemctl start mysqld
sleep 5s # 等待服务启动
systemctl status mysqld

if systemctl is-active --quiet mysqld; then
    echo "MySQL 服务启动成功"
else
    echo "MySQL 服务启动失败"
    exit 1
fi

# 清理
rm -rf /opt/mysql-8.0.43-linux-glibc2.28-x86_64

echo "🎉 MySQL 8.0.43 安装完成！"
echo " 登录命令和临时密码为: ${MYSQL_BASE}/bin/mysql -u root -p${TEMP_PASS}"
echo "配置文件为: $MYCNF_PATH"
echo "数据目录为: ${MYSQL_BASE}/data"   
echo "修改登录密码......."
/usr/local/mysql/bin/mysql -uroot -p"${TEMP_PASS}" --connect-expired-password \
-e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_PASSWORD}';"


echo "部署完成!!!"
