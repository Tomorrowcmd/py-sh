#!/bin/bash

# =================================================================
# 脚本名称: ops_tool.sh
# 适用环境: 麒麟/统信/CentOS (信创主流环境)
# 功能描述: 自动化巡检、一键安装、日志清理、定时备份
# =================================================================

# --- 全局变量配置 ---
BACKUP_SRC="/data/app/conf"       # 需要备份的配置目录
BACKUP_DEST="/data/backup"        # 备份存放路径
LOG_DIR="/data/app/logs"          # 日志目录
INSTALL_DIR="/usr/local/nginx"    # 安装路径
LOG_FILE="/var/log/ops_daily.log" # 脚本运行日志

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

# --- 1. 日常巡检函数 ---
function check_system() {

    # 使用 -e 参数启用转义字符解释，让颜色代码生效
    echo -e "${YELLOW} --- 开始系统巡检 --- ${NC}"
    # 查看系统负载
    echo -e "系统负载: $(uptime | awk -F 'load average:' '{print $2}')"
    # 磁盘空间检查(只列出占用超过80%的分区，加0表示转换成数字)
    echo -e "磁盘预警: "
    df -h | awk '$5 + 0 > 80 {print $0}'
    # 内存使用率，已用内存占总内存的百分比
    free -m | awk 'NR==2{printf "内存使用率: %.2f%%\n", $3*100/$2}'
    # 检查核心服务状态 (以SSH为例)
    systemctl is-active --quiet sshd && echo "SSH服务: 运行中" || echo -e "${RED}SSH服务: 已停止${NC}"
    echo -e "${GREEN} 巡检完成！${NC}\n"

}

# --- 2. 一键安装函数(Nginx为例，信创常做负载均衡) ----
function install_nginx() {
    echo -e "${YELLOW} --- 开始一键安装 Nginx --- ${NC}"
    # 检查是否已安装
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${RED}Nginx 已安装，请勿重复安装！${NC}"
        return
    fi

    # 下载并编译 (此处演示逻辑)
    echo "正在从内网仓库获取安装包..."
    # wget http://internal-repo/nginx-1.24.0.tar.gz
    # tar -zxvf nginx-1.24.0.tar.gz ... && make && make install

    echo -e "${GREEN}Nginx 模拟安装成功！位置：$INSTALL_DIR ${NC}\n"
}

# --- 3. 日志清理函数 ---
function clean_logs() {
    echo -e "${YELLOW}----开始清理 7 天前的日志 ---${NC}"
    if [ -d "$LOG_DIR" ]; then
      # 记录删除的文件名到日志
      find "$LOG_DIR" -name "*.log" -mtime +7 -type f > /tmp/deleted_logs.txt
      find "$LOG_DIR" -name "*.log" -mtime +7 -type f -delete
      echo "已清理 $(wc -l < /tmp/deleted_logs.txt)个日志文件。"
    else
      echo -e "日志文件不存在，跳过。"
    fi
    echo -e "${GREEN}清理完成! ${NC}\n"
}

# 逻辑分发
case "$1" in
  start) check_system ;;
  clean) clean_logs ;;
  *) echo "Usage: $0 {start|clean}" ;;
esac


# ----4. 自动化备份函数 ----
function backup_data() {
    echo -e "${YELLOW} --- 开始数据备份 ---${NC}"
    DATE=$(date +%Y%m%d_%H%M%S)
    FILE_NAME="backup_conf_$DATE.tar.gz"

    [ ! -d "$BACKUP_DEST" ] && mkdir -p "$BACKUP_DEST"

    tar -czf "$BACKUP_DEST/$FILE_NAME" "$BACKUP_SRC" &> /dev/null

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}备份成功: $BACKUP_DEST/$FILE_NAME${NC}"
      # 只保留最近30天的备份
      find "$BACKUP_DEST" -name "backup_conf_*"
    else
      echo -e "${RED}备份失败! ${NC}"
    fi
}

# ---- 菜单交互逻辑 ----
function show_menu() {
    echo "=============================="
    echo "    运维自动化工具箱"
    echo "=============================="
    echo "1. 系统日常巡检"
    echo "2. 一键安装Nginx"
    echo "3. 日志自动清理"
    echo "4. 数据定时备份"
    echo "5. 执行全部任务"
    echo "q. 退出"
    echo "=============================="
    read -p "请输入选项: " choice
}

while true; do
  show_menu
  case $choice in
    1) check_system ;;
    2) install_nginx ;;
    3) clean_logs ;;
    4) backup_data ;;
    5) check_system; clean_logs; backup_data ;;
    q) exit 0 ;;
    *) echo -e "${RED}无效选项，请重新输入${NC}" ;;
  esac
done
