#!/bin/bash

# 项目配置映射 (项目名:jar文件名)
declare -A PROJECT_JARS=(
    ["app"]="app.jar"
    # 可以在这里添加更多项目
    # ["project2"]="project2.jar"
    # ["project3"]="project3.jar"
)

# 全局变量
PROJECT_NAME=""
JAR_NAME=""
PID_FILE=""
LOG_FILE=""
CONFIG_FILE_DEFAULT=""

# 初始化项目配置
init_project() {
    local project="$1"
    
    if [[ -z "$project" ]]; then
        echo "错误: 必须使用 -p 参数指定项目名称"
        echo "使用 '$0 help' 查看帮助信息"
        exit 1
    fi
    
    PROJECT_NAME="$project"
    if [[ -n "${PROJECT_JARS[$project]}" ]]; then
        JAR_NAME="${PROJECT_JARS[$project]}"
    else
        JAR_NAME="${project}.jar"
    fi
    
    PID_FILE="${PROJECT_NAME}.pid"
    LOG_FILE="${PROJECT_NAME}.log"
    CONFIG_FILE_DEFAULT="${PROJECT_NAME}.properties"
    
    # 检查jar文件是否存在
    if [[ ! -f "$JAR_NAME" ]]; then
        echo "错误: JAR文件不存在: $JAR_NAME"
        echo "请确保项目 '$PROJECT_NAME' 的JAR文件存在"
        exit 1
    fi
}

start() {
  local project=""
  PROPERTIES_ARG=""
  CONFIG_MODE=0
  CONFIG_FILE=""
  BACKGROUND=0
  SHOW_LOG=0

  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          project="$2"
          shift
        else
          echo "错误: -p 参数需要指定项目名称"
          exit 1
        fi
        ;;
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
  
  # 初始化项目配置
  init_project "$project"

  if [[ $CONFIG_MODE -eq 1 ]]; then
    if [[ -z "$CONFIG_FILE" ]]; then
      if [[ -f "$CONFIG_FILE_DEFAULT" ]]; then
        CONFIG_FILE="$CONFIG_FILE_DEFAULT"
      elif [[ -f "application.properties" ]]; then
        CONFIG_FILE="application.properties"
      else
        echo "未指定配置文件，且当前目录下无 $CONFIG_FILE_DEFAULT 或 application.properties"
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
    echo "项目 '$PROJECT_NAME' 已在运行，PID: $(awk '{print $1}' $PID_FILE)"
    exit 1
  fi

  if [[ $BACKGROUND -eq 1 ]]; then
    if [[ $SHOW_LOG -eq 1 ]]; then
      nohup java -jar "$JAR_NAME" $PROPERTIES_ARG > "$LOG_FILE" 2>&1 &
      echo "$! BACKGROUND" > "$PID_FILE"
      echo "项目 '$PROJECT_NAME' 已后台启动，PID: $(awk '{print $1}' $PID_FILE)"
      tail -f "$LOG_FILE"
    else
      nohup java -jar "$JAR_NAME" $PROPERTIES_ARG > /dev/null 2>&1 &
      echo "$! BACKGROUND" > "$PID_FILE"
      echo "项目 '$PROJECT_NAME' 已后台启动（无日志记录），PID: $(awk '{print $1}' $PID_FILE)"
    fi
  else
    java -jar "$JAR_NAME" $PROPERTIES_ARG
    echo "$! FOREGROUND" > "$PID_FILE"
  fi
}


stop() {
  local project=""
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          project="$2"
          shift
        else
          echo "错误: -p 参数需要指定项目名称"
          exit 1
        fi
        ;;
    esac
    shift
  done
  
  # 初始化项目配置（不检查jar文件存在性）
  if [[ -z "$project" ]]; then
    echo "错误: 必须使用 -p 参数指定项目名称"
    echo "使用 '$0 help' 查看帮助信息"
    exit 1
  fi
  PROJECT_NAME="$project"
  PID_FILE="${PROJECT_NAME}.pid"
  
  if [ -f "$PID_FILE" ]; then
    PID=$(awk '{print $1}' "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
      kill $PID
      echo "发送停止信号给项目 '$PROJECT_NAME'，等待进程退出..."
      for i in {1..10}; do
        sleep 1
        if ! kill -0 $PID 2>/dev/null; then
          echo "项目 '$PROJECT_NAME' 已停止"
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
    echo "未找到项目 '$PROJECT_NAME' 的 PID 文件，应用可能未运行"
  fi
}

status() {
  local project=""
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          project="$2"
          shift
        else
          echo "错误: -p 参数需要指定项目名称"
          exit 1
        fi
        ;;
    esac
    shift
  done
  
  # 初始化项目配置（不检查jar文件存在性）
  if [[ -z "$project" ]]; then
    echo "错误: 必须使用 -p 参数指定项目名称"
    echo "使用 '$0 help' 查看帮助信息"
    exit 1
  fi
  PROJECT_NAME="$project"
  PID_FILE="${PROJECT_NAME}.pid"
  LOG_FILE="${PROJECT_NAME}.log"
  
  if [ -f "$PID_FILE" ]; then
    PID=$(awk '{print $1}' "$PID_FILE")
    MODE=$(awk '{print $2}' "$PID_FILE")
    if kill -0 $PID 2>/dev/null; then
      echo "项目 '$PROJECT_NAME' 正在运行，PID: $PID"
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
      if [ -f "$LOG_FILE" ]; then
        LOG_SIZE=$(du -h "$LOG_FILE" | awk '{print $1}')
        echo "日志文件: $LOG_FILE (大小: $LOG_SIZE)"
        echo "日志最近10行："
        tail -n 10 "$LOG_FILE"
      else
        echo "日志文件: $LOG_FILE 不存在"
      fi
    else
      echo "项目 '$PROJECT_NAME' 未运行，但 PID 文件存在"
    fi
  else
    echo "项目 '$PROJECT_NAME' 未运行"
  fi
}

log() {
  local project=""
  
  # 解析参数
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p)
        if [[ -n "$2" && ! "$2" =~ ^- ]]; then
          project="$2"
          shift
        else
          echo "错误: -p 参数需要指定项目名称"
          exit 1
        fi
        ;;
    esac
    shift
  done
  
  # 初始化项目配置（不检查jar文件存在性）
  if [[ -z "$project" ]]; then
    echo "错误: 必须使用 -p 参数指定项目名称"
    echo "使用 '$0 help' 查看帮助信息"
    exit 1
  fi
  PROJECT_NAME="$project"
  LOG_FILE="${PROJECT_NAME}.log"
  
  if [ -f "$LOG_FILE" ]; then
    tail -f "$LOG_FILE"
  else
    echo "项目 '$PROJECT_NAME' 的日志文件 $LOG_FILE 不存在"
  fi
}

list() {
  echo "所有项目状态："
  echo "==========================================="
  
  # 检查配置中的项目
  for project in "${!PROJECT_JARS[@]}"; do
    local pid_file="${project}.pid"
    if [ -f "$pid_file" ]; then
      local pid=$(awk '{print $1}' "$pid_file")
      if kill -0 $pid 2>/dev/null; then
        echo "✓ $project - 运行中 (PID: $pid)"
      else
        echo "✗ $project - 已停止 (PID文件存在但进程不存在)"
      fi
    else
      echo "○ $project - 未运行"
    fi
  done
  
  # 检查其他可能的项目（通过.pid文件）
  for pid_file in *.pid; do
    if [ -f "$pid_file" ]; then
      local project_name=$(basename "$pid_file" .pid)
      local is_known=false
      
      # 检查是否是已知项目
      for known_project in "${!PROJECT_JARS[@]}"; do
        if [[ "$project_name" == "$known_project" ]]; then
          is_known=true
          break
        fi
      done
      
      # 如果是未知项目，显示它
      if [[ "$is_known" == false ]]; then
        local pid=$(awk '{print $1}' "$pid_file")
        if kill -0 $pid 2>/dev/null; then
          echo "✓ $project_name (未配置) - 运行中 (PID: $pid)"
        else
          echo "✗ $project_name (未配置) - 已停止 (PID文件存在但进程不存在)"
        fi
      fi
    fi
  done
  
  # 如果没有找到任何项目
  if [[ ${#PROJECT_JARS[@]} -eq 0 ]]; then
    echo "未配置任何项目"
    echo "请在脚本顶部的 PROJECT_JARS 数组中添加项目配置"
  fi
}

help() {
  echo "用法: $0 {start|stop|status|log|list|help} [选项]"
  echo ""
  echo "命令说明："
  echo "  start   启动应用，默认前台运行，可选后台运行和日志输出"
  echo "  stop    停止应用"
  echo "  status  查看应用运行状态"
  echo "  log     实时查看应用日志"
  echo "  list    显示所有项目的运行状态"
  echo "  help    显示本帮助信息"
  echo ""
  echo "选项说明："
  echo "  -p [name]   指定项目名称（必需参数）"
  echo "  -n          后台运行，不记录日志 (仅用于 start)"
  echo "  -l          启动后自动输出日志 (仅用于 start，且仅后台运行时有效)"
  echo "  -c [file]   指定配置文件路径 (仅用于 start)"
  echo ""
  echo "项目配置："
  if [[ ${#PROJECT_JARS[@]} -gt 0 ]]; then
    echo "  已配置项目: ${!PROJECT_JARS[*]}"
  else
    echo "  未配置任何项目"
  fi
  echo "  可以在脚本顶部的 PROJECT_JARS 数组中添加更多项目配置"
  echo ""
  echo "用法示例："
  echo "  $0 start -p smartlamp           # 启动指定项目（前台运行）"
  echo "  $0 start -p myapp -n            # 后台启动指定项目"
  echo "  $0 start -p myapp -n -l         # 后台启动指定项目并显示日志"
  echo "  $0 start -p myapp -c myapp.properties    # 使用指定配置文件启动项目"
  echo "  $0 start -p myapp -c /path/to/config.properties -n -l"
  echo "                                  # 完整示例：指定项目、配置、后台运行并显示日志"
  echo "  $0 stop -p myapp                # 停止指定项目"
  echo "  $0 status -p myapp              # 查看指定项目状态"
  echo "  $0 log -p myapp                 # 查看指定项目日志"
  echo "  $0 list                         # 显示所有项目状态"
  echo "  $0 help                         # 显示帮助信息"
}

case "$1" in
  start)
    start "${@:2}"
    ;;
  stop)
    stop "${@:2}"
    ;;
  status)
    status "${@:2}"
    ;;
  log)
    log "${@:2}"
    ;;
  list)
    list
    ;;
  help)
    help
    ;;
  *)
    help
    exit 1
    ;;
esac
