#!/bin/bash

JAR_NAME="smartlamp.jar"
PID_FILE="app.pid"

start() {
  PROPERTIES_ARG=""
  CONFIG_MODE=0
  CONFIG_FILE=""
  BACKGROUND=0
  SHOW_LOG=0

  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c)
        CONFIG_MODE=1
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          CONFIG_FILE="$2"
          shift
        fi
        ;;
      -n)
        BACKGROUND=1
        ;;
      -l)
        SHOW_LOG=1
        ;;
    esac
    shift
  done

  if [[ $CONFIG_MODE -eq 1 ]]; then
    if [[ -z "$CONFIG_FILE" ]]; then
      if [[ -f "application.properties" ]]; then
        CONFIG_FILE="application.properties"
      else
        echo "未指定配置文件，且当前目录下无 application.properties"
        exit 1
      fi
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
      echo "配置文件不存在: $CONFIG_FILE"
      exit 1
    fi
    PROPERTIES_ARG="--spring.config.location=$CONFIG_FILE"
    echo "使用配置文件: $CONFIG_FILE"
  fi

  if [ -f "$PID_FILE" ] && kill -0 $(awk '{print $1}' "$PID_FILE") 2>/dev/null; then
    echo "应用已在运行，PID: $(awk '{print $1}' $PID_FILE)"
    exit 1
  fi

  if [[ $BACKGROUND -eq 1 ]]; then
    if [[ $SHOW_LOG -eq 1 ]]; then
      nohup java -jar "$JAR_NAME" $PROPERTIES_ARG > app.log 2>&1 &
      echo "$! BACKGROUND" > "$PID_FILE"
      echo "应用已后台启动，PID: $(awk '{print $1}' $PID_FILE)"
      tail -f app.log
    else
      nohup java -jar "$JAR_NAME" $PROPERTIES_ARG > /dev/null 2>&1 &
      echo "$! BACKGROUND" > "$PID_FILE"
      echo "应用已后台启动（无日志记录），PID: $(awk '{print $1}' $PID_FILE)"
    fi
  else
    java -jar "$JAR_NAME" $PROPERTIES_ARG
    echo "$! FOREGROUND" > "$PID_FILE"
  fi
}


stop() {
  if [ -f "$PID_FILE" ]; then
    PID=$(awk '{print $1}' "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
      kill $PID
      echo "发送停止信号，等待进程退出..."
      for i in {1..10}; do
        sleep 1
        if ! kill -0 $PID 2>/dev/null; then
          echo "应用已停止"
          rm -f "$PID_FILE"
          return
        fi
      done
      echo "进程未正常退出，强制杀死"
      kill -9 $PID
      rm -f "$PID_FILE"
    else
      echo "未找到运行中的进程"
      rm -f "$PID_FILE"
    fi
  else
    echo "未找到 PID 文件，应用可能未运行"
  fi
}

status() {
  if [ -f "$PID_FILE" ]; then
    PID=$(awk '{print $1}' "$PID_FILE")
    MODE=$(awk '{print $2}' "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
      echo "应用正在运行，PID: $PID"
      if command -v ps >/dev/null 2>&1; then
        START_TIME=$(ps -p $PID -o lstart=)
        CMD_LINE=$(ps -p $PID -o cmd=)
        RSS=$(ps -p $PID -o rss= | awk '{printf "%.2f MB", $1/1024}')
        VSZ=$(ps -p $PID -o vsz= | awk '{printf "%.2f MB", $1/1024}')
        CPU=$(ps -p $PID -o %cpu=)
        THREADS=$(ps -p $PID -o nlwp=)
        echo "启动时间: $START_TIME"
        echo "进程命令: $CMD_LINE"
        echo "运行方式: $([ "$MODE" = "BACKGROUND" ] && echo 后台 || echo 前台)"
        echo "物理内存(RSS): $RSS"
        echo "虚拟内存(VSZ): $VSZ"
        echo "CPU占用率: $CPU %"
        echo "线程数: $THREADS"
      fi
      if [ -f "app.log" ]; then
        LOG_SIZE=$(du -h app.log | awk '{print $1}')
        echo "日志文件: app.log (大小: $LOG_SIZE)"
        echo "日志最近10行："
        tail -n 10 app.log
      else
        echo "日志文件: app.log 不存在"
      fi
    else
      echo "应用未运行，但 PID 文件存在"
    fi
  else
    echo "应用未运行"
  fi
}

log() {
  if [ -f "app.log" ]; then
    tail -f app.log
  else
    echo "日志文件 app.log 不存在"
  fi
}

help() {
  echo "用法: $0 {start|stop|status|log|help} [选项]"
  echo ""
  echo "命令说明："
  echo "  start   启动应用，默认前台运行，可选后台运行和日志输出"
  echo "  stop    停止应用"
  echo "  status  查看应用运行状态"
  echo "  log     实时查看应用日志 (tail -f app.log)"
  echo "  help    显示本帮助信息"
  echo ""
  echo "选项说明（用于 start 命令）："
  echo "  -n          后台运行，不记录日志"
  echo "  -l          启动后自动输出日志 (tail -f app.log，仅后台运行时有效)"
  echo "  -c [file]   指定配置文件路径，若不指定则查找当前目录下 application.properties"
  echo ""
  echo "用法示例："
  echo "  $0 start                # 前台运行，日志输出到终端"
  echo "  $0 start -n             # 后台运行，不记录日志"
  echo "  $0 start -n -l          # 后台运行并记录日志且 tail 日志"
  echo "  $0 start -c             # 前台运行，自动查找 application.properties"
  echo "  $0 start -n -c /path/app-prod.properties -l   # 后台运行，指定配置文件并记录日志"
  echo "  $0 stop                 # 停止应用"
  echo "  $0 status               # 查看应用状态"
  echo "  $0 log                  # 实时查看日志"
  echo "  $0 help                 # 查看帮助信息"
}

case "$1" in
  start)
    start "${@:2}"
    ;;
  stop)
    stop
    ;;
  status)
    status
    ;;
  log)
    log
    ;;
  help)
    help
    ;;
  *)
    help
    exit 1
    ;;
esac
