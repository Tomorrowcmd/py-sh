#!/bin/bash

# 设置错误处理,出错时不往下执行
# set -ex
set -e


apt update
apt upgrade -y


apt list -a redis-server
apt install -y redis-server
systemctl status redis-server
redis-server --version
#bind 127.0.0.1 ::1
#requirepass 111111
