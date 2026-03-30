#!/bin/bash

# 设置错误处理,出错时不往下执行
# set -ex
set -e

# ================= 配置区域 =================
# 主要部署的目录sw
MYSQL_TAR_XZ_PATH=/opt/mysql-8.0.45-linux-glibc2.28-x86_64.tar.xz
MYSQL_INSTALL_PATH=/usr/local/mysql8
MYSQL_DATA=$MYSQL_INSTALL_PATH/data
# 初始化临时密码存储路径
# 优化：确保密码存放目录存在
MYSQL_PASS_DIR=$MYSQL_INSTALL_PATH/tmp
MYSQL_PASS_FILE=$MYSQL_PASS_DIR/mysql_temp_password.txt
# 数据库配置文件路径
MYSQL_MY_CNF=/etc/my.cnf
# 自启动文件
MYSQL_SYSTEMD_SERVICE=/etc/systemd/system/mysqld.service
# 3. 定义你想要设置的新密码
# 注意：MySQL 8.0 默认开启密码强度插件，如果报错，请换成复杂密码如 Root@123456
NEW_MYSQL_PASS="Root@1234"

# ================= 环境准备 =================
echo "1. 正在检查环境..."

# 校验安装包是否存在
if [ ! -f "$MYSQL_TAR_XZ_PATH" ]; then
    echo "错误：找不到安装包 $MYSQL_TAR_XZ_PATH"
    exit 1
fi

# 创建 mysql 组和用户（不允许直接登录系统，提高安全性）
# -r 表示创建系统用户不用于登录系统，-g指定用户组, -s指定用户登录shell
# 优化：判断用户是否存在，避免重复执行报错
groupadd mysql || true
useradd -r -g mysql -s /bin/false mysql || true

# ================= 解压与权限 =================
echo "2. 正在解压安装包..."
# 创建解压后的安装目录
mkdir -p $MYSQL_INSTALL_PATH
# -x → 解压, -J → 处理 .xz 格式，-f → 指定文件
tar -xJf $MYSQL_TAR_XZ_PATH -C $MYSQL_INSTALL_PATH --strip-components=1 > /dev/null 2>&1

# 创建数据存储目录
mkdir -p $MYSQL_DATA
mkdir -p $MYSQL_PASS_DIR

# 更改权限：让mysql用户拥有该目录的权限
chown -R mysql:mysql $MYSQL_INSTALL_PATH
chmod 750 $MYSQL_DATA

# ================= 初始化 =================
echo "3. 正在初始化数据库..."
cd $MYSQL_INSTALL_PATH
# $NF表示最后一列
# 优化：2>&1 确保抓取到 stderr 中的临时密码
TEMP_PASS=$(./bin/mysqld --initialize --user=mysql --basedir=$MYSQL_INSTALL_PATH --datadir=$MYSQL_DATA 2>&1 | grep 'temporary password' | awk '{print $NF}')

# 文件校验
if [ -z "$TEMP_PASS" ]; then
    echo "错误：未能获取到临时密码，请检查 $MYSQL_DATA 是否为空或日志输出。"
    exit 1
else 
    echo "初始化成功！"
    echo "$TEMP_PASS" > $MYSQL_PASS_FILE
    # 优化：限制密码文件权限
    chown mysql:mysql $MYSQL_PASS_FILE
    chmod 600 $MYSQL_PASS_FILE
fi

# ================= 配置文件 =================
echo "4. 正在配置 my.cnf 和 systemd..."
# 编写配置文件 my.cnf
cat > $MYSQL_MY_CNF << EOF
[mysqld]
basedir=$MYSQL_INSTALL_PATH
datadir=$MYSQL_DATA
socket=/tmp/mysql.sock
user=mysql
port=3306
collation-server=utf8mb4_general_ci
log-error=$MYSQL_DATA/mysql.err
pid-file=$MYSQL_DATA/mysql.pid
# 避免 DNS 解析延迟
skip-name-resolve

[client]
socket=/tmp/mysql.sock
default-character-set=utf8mb4
EOF

# 配置自启动文件
# 优化：转义 \$MAINPID 防止在生成文件时被 shell 提前解析
cat > $MYSQL_SYSTEMD_SERVICE << EOF
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=forking
User=mysql
Group=mysql
ExecStart=$MYSQL_INSTALL_PATH/support-files/mysql.server start
ExecStop=$MYSQL_INSTALL_PATH/support-files/mysql.server stop
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# ================= 环境变量 =================
# 优化：添加环境变量配置，方便直接使用 mysql 命令
if ! grep -q "$MYSQL_INSTALL_PATH/bin" /etc/profile; then
    echo "export PATH=\$PATH:$MYSQL_INSTALL_PATH/bin" >> /etc/profile
fi

# ================= 启动服务 =================
echo "5. 正在启动 MySQL 服务..."
# 修改环境变量配置文件之后需要重载一下
# 注意：source 在脚本内执行仅对脚本后续进程有效
source /etc/profile || true

# 重新加载系统服务
systemctl daemon-reload
# 启动并设置自启
systemctl start mysqld
# 等待几秒确保服务完全启动
echo "正在等待 MySQL 服务就绪..."
sleep 5
systemctl enable mysqld
# systemctl status mysqld

# ================= 修改密码与远程权限 =================
echo "6. 正在自动修改初始密码并开启远程访问..."

# 使用刚才初始化时保存的那个密码登录
# 从之前保存的文件中读取临时密码
if [ -f "$MYSQL_PASS_FILE" ]; then
    TEMP_PASS=$(cat $MYSQL_PASS_FILE)
else
    echo "错误：找不到临时密码文件 $MYSQL_PASS_FILE"
    exit 1
fi

# --connect-expired-password:
# 这是 MySQL 8.0 客户端的一个重要参数。因为初始化生成的密码默认是“过期的”，如果不带这个参数，直接执行命令可能会被拒绝。
# 这种写法允许你在 Shell 脚本中直接嵌入多行 SQL 命令，并一次性 “喂” 给 mysql 客户端，而不需要人工交互。

# ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '$NEW_MYSQL_PASS'; mysql 8 可能没有这个用户
$MYSQL_INSTALL_PATH/bin/mysql --connect-expired-password -u root -p"$TEMP_PASS" << EOF
-- 1. 修改本地 root 密码
ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_MYSQL_PASS';

-- 2. 开启远程访问权限
DROP USER IF EXISTS 'root'@'%';
CREATE USER 'root'@'%' IDENTIFIED BY '$NEW_MYSQL_PASS';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- 3. 刷新权限
FLUSH PRIVILEGES;

-- 注意：这里不需要 EXIT; 
EOF

# ================= 收尾工作 =================
# 建议：出于安全考虑，任务完成后删除包含临时密码的文件
rm -f $MYSQL_PASS_FILE

echo "----------------------------------------------------"
echo "MySQL 自动部署完成！"
echo "Root 新密码已设置为: $NEW_MYSQL_PASS"
echo "MySQL 配置文件路径: $MYSQL_MY_CNF"
echo "请手动执行以下命令使环境变量生效:"
echo "source /etc/profile"
echo "systemctl status mysqld 可查看MySQL运行状态"
echo "----------------------------------------------------"