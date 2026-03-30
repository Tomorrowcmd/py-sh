#!/bin/bash

# --- 变量定义 ---
APP_NAME="my-project.jar"
APP_PATH="/data/app/my-project"
PID_FILE="$APP_PATH/app.pid"
LOG_FILE="$APP_PATH/console.log"

# 检查目录是否存在
[ ! -d "$APP_PATH/logs" ] && mkdir -p "$APP_PATH/logs"

# 核心函数，停止
stop() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo "正在停止应用 (PID: $PID)..."
    kill "$PID"
    # 等待 5 秒，如果还没死就强制杀掉
    sleep 5
    if ps -p "$PID" > /dev/null; then
      echo "应用未停止，强制杀死..."
      kill -9 "$PID"
    fi
    rm -f "$PID_FILE"
    echo "应用已停止"
  else
    echo "未发现 PID 文件, 应用可能未运行"
  fi
}

# 核心函数：启动
start() {
  # 检查是否已经正在运行
  if [ -f "PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null; then
    echo "应用已经在运行中(PID: $(cat $PID_FILE))"
    exit 1
  fi

  echo "正在启动 $APP_NAME..."
#  nohup java -Xms512m -Xmx1024m -jar "$APP_PATH/$APP_NAME" > "$LOG_FILE" 2>&1 &
  nohup sleep 1000 > "$LOG_FILE" 2>&1 &

  # 将新产生的 PID 写入文件，$!获取后台运行的最后一个进程的ID
  echo $! > "$PID_FILE"
  echo "启动成功，PID: $!"
}

# --- 核心函数: 状态 ----
status() {
  if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null; then
    echo "应用状态：运行中 PID: $(cat $PID_FILE)"
  else
    echo "应用状态：未运行"
  fi
}

# 逻辑分发
case "$1" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  status) status ;;
  *) echo "用法: $0 {start|stop|restart|status}" ;;
esac