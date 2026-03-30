#!/bin/bash

# 设置错误处理,出错时不往下执行
# set -ex
set -e


apt update
apt upgrade -y

apt list -a mysql-server

apt install -y mysql-server

systemctl status mysql


#CREATE USER 'admin'@'%' IDENTIFIED BY 'ubuntu@123';
#
#GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
#FLUSH PRIVILEGES;

systemctl stop mysql.service

vim /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql.service
