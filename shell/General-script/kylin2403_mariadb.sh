#!/bin/bash
INSTALL_BASE="/opt"     # 初始化路径
SQL_FILE="safetydocument-260210全量脚本.sql"       # 数据库初始化脚本
DB_NAME="safetydocument" # 数据库名


# ---  MariaDB 配置与初始化 ---
echo "▶ 1/4 正在配置 MariaDB...请稍后..."
MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf"

if [ -f "$MARIADB_CONF" ]; then
    # 检查并添加 lower_case_table_names
    if ! grep -q "lower_case_table_names" "$MARIADB_CONF"; then
        sed -i '/\[mysqld\]/a lower_case_table_names = 1' "$MARIADB_CONF"
        echo "✔ 已开启表名忽略大小写"
    fi

    # 检查并添加 bind-address   这里根据实际情况开启数据库远程访问，默认不开启，如果需要开启请取消注释
    # if ! grep -q "bind-address" "$MARIADB_CONF"; then
    #     sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' "$MARIADB_CONF"
    #     echo "✔ 已设置允许远程连接 (0.0.0.0)"
    # fi
else
    echo "❌ 错误：未找到 $MARIADB_CONF"
    exit 1
fi

# 设置开机自启并立即启动 MariaDB 服务
systemctl enable mariadb --now

echo "▶ 正在初始化数据库内容..."
  if [ ! -f "$INSTALL_BASE/$SQL_FILE" ]; then
    echo "⚠️ 警告：未找到 SQL 脚本 $SQL_FILE，跳过导入"
else
    # 自动执行密码修改与建库导入
    mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';
ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY 'root';
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE ${DB_NAME};
SOURCE ${INSTALL_BASE}/${SQL_FILE};

CREATE USER 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
ALTER USER 'root'@'%' IDENTIFIED BY 'root';
FLUSH PRIVILEGES;
EOF
    echo "✔ 数据库 $DB_NAME 初始化完成"
fi

echo "▶ MariaDB 配置与初始化完成！默认账户密码都为 root，请务必修改以确保安全！"