#!/bin/bash
#
#set -e  # 出错自动退出,某条命令的执行返回结果不等于0则整个脚本自动退出

echo "======开始部署自监管所有中间件======="

chmod +x esInstall.sh
chmod +x kafkaInstall2.13-3.6.2.sh
chmod +x minio21Install.sh
chmod +x redisInstall.sh

echo "=======正在安装redis========"
sleep 3
./redisInstall.sh

echo "=======正在安装kafka========"
sleep 3
./kafkaInstall2.13-3.6.2.sh

echo "=======正在安装minio========"
sleep 3
./minio21Install.sh

echo "=======正在安装elasticsearch========"
sleep 3
./esInstall.sh

echo "=============================="
echo "=============================="
echo "=============================="
echo "=========所有中间件安装完成========="
