#!/system/bin/sh

export LD_LIBRARY_PATH=/system_ext/lib64:$LD_LIBRARY_PATH
export PATH=/system_ext/bin:$PATH
export LD_PRELOAD=/system_ext/lib64/libandroid-shmem-aarch64-linux-androideabi26.so

PG_CTL="/system_ext/bin/pg_ctl" # pg_ctl命令路径
PG_RESETWAL="/system_ext/bin/pg_resetwal" #pg_resetwal命令路径
PG_DATA="/data/ebase/data" # 数据目录路径
LOG_FILE="/data/ebase/log" # 日志文件
START_LOG_FILE="/data/ebase/startlog" # 启动日志文件，采用覆盖模式
PG_POSTMATSTER_ID="$PG_DATA/postmaster.pid" # postmaster.pid文件路径
PG_SOCKET_DIR="/data/ebase/tmp" # unix socket目录
PG_PORT="6789"
PORT_LOCK="$PG_SOCKET_DIR/.s.PGSQL.$PG_PORT.lock"

MAX_RETRIES=5 # 最大重试次数
RETRY_COUNT=0 # 初始化重试计数器

FINAL_STARTUP_SUCCESS="0"
PORT_OCCUPIED="3"
TIME_OUT="4"
CONFIGURE_FILE_ERROR="5"
NO_SPACE_ERROR="6"
NO_MEM_ERROR="7"
FINAL_STARTUP_FAIL="10"


echo "" >> "$LOG_FILE" 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') start ebase " >> "$LOG_FILE" 2>&1

if "$PG_CTL" status -D "$PG_DATA" &> /dev/null; then
  echo "The database has been successfully started, restart!" >> "$LOG_FILE" 2>&1
  "$PG_CTL" restart -D "$PG_DATA" > "$START_LOG_FILE" 2>&1
else
  "$PG_CTL" start -D "$PG_DATA" > "$START_LOG_FILE" 2>&1
fi

RESULT=$?

while [ "$RESULT" -ne 0 ]; do
    # 增加重试计数器
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -gt "$MAX_RETRIES" ]; then
        echo "Maximum retries ($MAX_RETRIES) reached. Database failed to start, please check the configuration file." >> "$LOG_FILE" 2>&1
        # 如果什么都不行，reset wal，然后再启动一下
        "$PG_RESETWAL" "$PG_DATA" >> "$LOG_FILE" 2>&1
        "$PG_CTL" start -D "$PG_DATA" > "$START_LOG_FILE" 2>&1
        RESULT=$?
        if [[ "$RESULT" -ne 0 ]]; then
            setprop persist.sys.ebase_start.error "$TIME_OUT"
            exit "$TIME_OUT"
        fi
        # 成功，下面不走，到while不符合条件会不继续循环
        continue
    fi

    echo "Database startup failed" >> "$LOG_FILE" 2>&1

    if grep -q "could not create any TCP/IP sockets" "$START_LOG_FILE"; then
        # 额外检查数据库监听端口
        if netstat -an | grep -q ":$PG_PORT.*LISTEN"; then
            echo "Port $PG_PORT is occupied!" >> "$LOG_FILE" 2>&1
            setprop persist.sys.ebase_start.error "$PORT_OCCUPIED"
            exit "$PORT_OCCUPIED"
        fi
    elif grep -q "lock file .*postmaster.pid.* already exists" "$START_LOG_FILE"; then
        if [[ ! -f "$PG_POSTMATSTER_ID" ]]; then
            echo "postmaster.pid does not exist" >> "$LOG_FILE" 2>&1
        else
            rm -f "$PG_POSTMATSTER_ID" >> "$LOG_FILE" 2>&1
            if [[ $? -ne 0 ]]; then
                echo "Faile to delete postmaster.pid" >> "$LOG_FILE" 2>&1
            else
                echo "Success to delete postmaster.pid" >> "$LOG_FILE" 2>&1
            fi
        fi
    elif grep -q "lock file .*/tmp/.s.PGSQL.$PG_PORT.lock.* already exists" "$START_LOG_FILE"; then
        rm -f "$PORT_LOCK" >> "$LOG_FILE" 2>&1
        if [[ $? -ne 0 ]]; then
            echo "Faile to delete $PG_PORT.lock" >> "$LOG_FILE" 2>&1
        else
            echo "Success to delete $PG_PORT.lock" >> "$LOG_FILE" 2>&1
        fi
    # 配置文件出错，报错退出
    elif grep -q "configuration file .*/data/postgresql.conf.* contains errors" "$START_LOG_FILE"; then
        echo "There is an error in the configuration file, please check the configuration file." >> "$LOG_FILE" 2>&1
        setprop persist.sys.ebase_start.error "$CONFIGURE_FILE_ERROR"
        exit "$CONFIGURE_FILE_ERROR"
     # 存储不够
    elif grep -q "No space left on device" "$START_LOG_FILE"; then
        echo "No space left on device.Please check the disk space." >> "$LOG_FILE" 2>&1
        #是否需要增加重试次数判断，超过次数后再退出？
        setprop persist.sys.ebase_start.error "$NO_SPACE_ERROR"
        exit "$NO_SPACE_ERROR"
    else # 可能是内存不够
        available_mem=$(free -m | awk '/^Mem:/{print $4 + $6}')
        #如果获取失败，则不处理
        if [[ -z "$available_mem" ]] || (( available_mem < 0 )); then
            echo "Get available memory failed." >> "$LOG_FILE" 2>&1
        elif ((available_mem < 50)); then
            echo "Available memory($available_mem MB) is less than 50MB.Please free up memory and try again" >> "$LOG_FILE" 2>&1
            setprop persist.sys.ebase_start.error "$NO_MEM_ERROR"
            exit "$NO_MEM_ERROR"
        fi
    fi

    > "$START_LOG_FILE" # 清空文件内容
    sleep 1
    "$PG_CTL" start -D "$PG_DATA" > "$START_LOG_FILE" 2>&1
    RESULT=$?
done

# 检测数据库是否启动成功
echo "Detecting database status..." >> "$LOG_FILE" 2>&1
if "$PG_CTL" status -D "$PG_DATA" &> /dev/null; then
  echo "The database has been successfully started!" >> "$LOG_FILE" 2>&1
  setprop persist.sys.ebase_start.error "$FINAL_STARTUP_SUCCESS"
else
  echo "Startup failed, please check the startlog file:$START_LOG_FILE" >> "$LOG_FILE" 2>&1
  setprop persist.sys.ebase_start.error "$FINAL_STARTUP_FAIL"
  exit "$FINAL_STARTUP_FAIL"
fi

chmod 666 /data/ebase/log
chmod 666 /data/ebase/startlog

while true; do
    sleep 60000
done
