#!/bin/bash

# 设置错误处理,出错时不往下执行
# 注意：由于rpm -q在包未安装时返回非零状态，暂时关闭set -e
set -e
set -o pipefail # 管道中只要有一个环节报错，整个管道就报非零

echo "===========查看依赖环境==========="

# 待检查的包列表
CHECK_PKGS="gcc make readline-devel zlib-devel"
# 依赖环境数组
DEPEND_ARRAY=()

# postgresql 安装包
POSTGRES_TAR="postgresql-14.11.tar.gz"

# 循环检查每一个包
for pkg in $CHECK_PKGS; do
  # 检查包是否安装
  if ! rpm -q $pkg >/dev/null 2>&1; then
    # 如果未安装，添加到数组
    DEPEND_ARRAY+=($pkg)
  fi
done

# 检查数组长度
echo "===========检查依赖环境==========="
VAR_TEMP="n"
if [ ${#DEPEND_ARRAY[@]} -gt 0 ]; then
  echo "❌ 有依赖环境未安装, 建议先安装依赖环境: "
  # 遍历数组
  for pkg in "${DEPEND_ARRAY[@]}"
  do
    echo "该依赖环境未安装-----> $pkg"
    echo "是否继续往下安装，如果只缺少readline-devel，不影响安装，但是会缺少一些功能，比如sql命令补全，历史sql命令查看等,
          如果缺少其他依赖则必须挂载iso镜像进行安装下载"
    echo "是否继续安装？(y/n)"
    # 提示用户输入,并读取用户输入
    read -r answer
    if [[ $answer != "y" ]]; then
      echo "用户选择不继续安装，退出脚本"
      exit 1
    else
      VAR_TEMP="y"
    fi
  done
else
  echo "✅ 依赖环境已安装"
fi

echo "===========安装PostgreSQL==========="
cd /opt
# 解压安装包到当前目录
tar -zxf $POSTGRES_TAR
cd postgresql-14.11
# 创建日志文件保存编译的输出
echo "===========创建日志文件保存编译的输出==========="
mkdir -p /var/log/postgres
touch /var/log/postgres/postgres_install.log

# 编译配置参数
echo "===========编译配置参数==========="
if (( $VAR_TEMP == "y" )); then
  # 如果依赖没有安装完则使用这个编译命令
  ./configure --prefix=/usr/local/pg14 --without-readline 2>&1
else
  ./configure --prefix=/usr/local/pg14 2>&1
fi

# 编译安装
echo "===========编译安装==========="
echo "正在编译中，请稍后..."
make -j $(nproc) >> /var/log/postgres/postgres_install.log 2>&1 # 并行编译,使用所有CPU核心
echo "编译完成，开始安装..."
make install >> /var/log/postgres/postgres_install.log 2>&1 #
echo "✅ 安装完成"



# 初始化与环境配置
echo "===========初始化与环境配置==========="
groupadd postgres
useradd -g postgres postgres

# 创建数据目录
echo "===========创建数据目录==========="
mkdir -p /var/pg14/data
echo "✅ 创建数据目录完成"

chown -R postgres:postgres /var/pg14/data
chown postgres:postgres /usr/local/pg14
echo "✅ 设置数据目录权限完成"


# 设置环境变量
echo "=============设置环境变量============="
echo 'export PGHOME=/usr/local/pg14' >> /etc/profile
echo 'export PATH=$PGHOME/bin:$PATH' >> /etc/profile
echo 'export PGDATA=/var/pg14/data' >> /etc/profile
echo "✅ 设置环境变量完成"

source /etc/profile
echo "✅ 环境变量已生效"

# 初始化数据库
su - postgres
echo "✅ 切换到postgres用户"
# 使用 -c 参数，让系统切换到 postgres 用户去执行引号内的命令
su - postgres -c "initdb -D /var/pg14/data -E UTF8 --locale=en_US.UTF-8"
echo "✅ 初始化数据库完成"

# 启动服务
su - postgres -c "pg_ctl -D /var/pg14/data -l logfile start"
echo "✅ 启动数据库服务完成"

# 检查版本
su - postgres -c "psql --version"


# 后续如果需要开启远程访问需要另外配置


