#!/system/bin/sh

export LD_LIBRARY_PATH=/system_ext/lib64:$LD_LIBRARY_PATH
export PATH=/system_ext/bin:$PATH
export LD_PRELOAD=/system_ext/lib64/libandroid-shmem-aarch64-linux-androideabi26.so

touch /data/ebase/shmem
chmod 666  /data/ebase/shmem

PG_CTL="/system_ext/bin/pg_ctl" # pg_ctl命令路径
PG_RESETWAL="/system_ext/bin/pg_resetwal" #pg_resetwal命令路径
PG_INITDB="/system_ext/bin/initdb" # initdb命令路径
PG_PSQL="/system_ext/bin/psql" # psql命令路径
PG_EBASE="/data/ebase" # ebase目录路径
PG_CONF_BAK="/data/ebase/postgresql.conf" # 配置文件备份路径
PG_DATA="/data/ebase/data" # 数据目录路径
LOG_FILE="/data/ebase/log" # 日志文件
START_LOG_FILE="/data/ebase/startlog" # 启动日志文件，采用覆盖模式
PG_CONF="$PG_DATA/postgresql.conf" # 配置文件路径
PG_HBA="$PG_DATA/pg_hba.conf" # 认证配置路径
PG_POSTMATSTER_ID="$PG_DATA/postmaster.pid" # postmaster.pid文件路径
PG_SOCKET_DIR="/data/ebase/tmp" # unix socket目录
PG_PORT="6789"
PORT_LOCK="$PG_SOCKET_DIR/.s.PGSQL.$PG_PORT.lock"
DB_USER="root"  # 数据库用户
DB_PASSWORD="123" # 数据库密码

MAX_RETRIES=5 # 最大重试次数
RETRY_COUNT=0 # 初始化重试计数器

FINAL_STARTUP_SUCCESS="0"
NO_PG_CTL="1"
INITDB_ERROR="2"
PORT_OCCUPIED="3"
TIME_OUT="4"
CONFIGURE_FILE_ERROR="5"
NO_SPACE_ERROR="6"
NO_MEM_ERROR="7"
EDIT_PASSWORT_ERROR="8"
RESTART_FAIL="9"
FINAL_STARTUP_FAIL="10"

# 修改或添加参数并去掉注释
modify_or_add_parameter() {
    local param=$1
    local value=$2
    local file=$3

    # 如果参数存在并被注释，去掉注释并修改值
    if grep -qE "^[[:space:]]*#[[:space:]]*${param}[[:space:]]*=" "$file"; then
        sed -i "s|^[[:space:]]*#[[:space:]]*${param}[[:space:]]*=.*|${param} = ${value}|" "$file"
        echo "Updated ${param} to ${value} (removed comment) in ${file}."  >> "$LOG_FILE" 2>&1
    # 如果参数存在但未被注释，直接修改值
    elif grep -qE "^[[:space:]]*${param}[[:space:]]*=" "$file"; then
        sed -i "s|^[[:space:]]*${param}[[:space:]]*=.*|${param} = ${value}|" "$file"
        echo "Updated ${param} to ${value} in ${file}."  >> "$LOG_FILE" 2>&1
    # 如果参数不存在，添加到文件末尾
    else
        echo "${param} = ${value}" >> "$file"
        echo "Added ${param} = ${value} to ${file}."  >> "$LOG_FILE" 2>&1
    fi
}

echo "" >> "$LOG_FILE" 2>&1
echo "$(date '+%Y-%m-%d %H:%M:%S') init ebase " >> "$LOG_FILE" 2>&1

# 检查 pg_ctl 是否存在
if [[ ! -x "$PG_CTL" ]]; then
    echo "The pg_ctl command was not found or cannot be executed,please check the path: $PG_CTL" >> "$LOG_FILE" 2>&1
    setprop persist.sys.ebase_start.error "$NO_PG_CTL"
    exit "$NO_PG_CTL"
fi

# 检查数据目录是否存在，不存在，initdb初始化
if [[ ! -d "$PG_DATA" ]]; then
    echo "The data directory does not exist,initializing..." >> "$LOG_FILE" 2>&1
    "$PG_INITDB" -D "$PG_DATA" >> "$LOG_FILE" 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Failed to initialize data directory, please check permissions or configuration." >> "$LOG_FILE" 2>&1
        rm -rf "$PG_DATA" >> "$LOG_FILE" 2>&1
        echo "delete $PG_DATA" >> "$LOG_FILE" 2>&1
        setprop persist.sys.ebase_start.error "$INITDB_ERROR"
        exit "$INITDB_ERROR"
    fi
    # 修改 unix_socket_directories,shared_buffers 和 maintenance_work_mem
    modify_or_add_parameter "unix_socket_directories" "'$PG_SOCKET_DIR'" "$PG_CONF"
    modify_or_add_parameter "shared_buffers" "128MB" "$PG_CONF"
    modify_or_add_parameter "maintenance_work_mem" "128MB" "$PG_CONF"

    # 将postgresql.conf拷贝一份到/data/ebase
    cp "$PG_CONF" "$PG_EBASE"
    echo "Copied $PG_CONF to $PG_EBASE." >> "$LOG_FILE" 2>&1

else
    echo "The data directory already exists, skip initialization." >> "$LOG_FILE" 2>&1
fi

# 额外检查数据库监听端口
if netstat -an | grep -q ":$PG_PORT.*LISTEN"; then
  echo "Port $PG_PORT is occupied!" >> "$LOG_FILE" 2>&1
  setprop persist.sys.ebase_start.error "$PORT_OCCUPIED"
  exit "$PORT_OCCUPIED"
fi

echo "Attempt to start database..." >> "$LOG_FILE" 2>&1

"$PG_CTL" start -D "$PG_DATA" > "$START_LOG_FILE" 2>&1
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
            echo "After reset wal, database startup failed " >> "$LOG_FILE" 2>&1
            setprop persist.sys.ebase_start.error "$TIME_OUT"
            exit "$TIME_OUT"
        fi
        # 成功，下面不走，到while不符合条件会不继续循环
        continue
    fi

    echo "Database startup failed" >> "$LOG_FILE" 2>&1
    if grep -q "lock file .*postmaster.pid.* already exists" "$START_LOG_FILE"; then
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
        # 删除conf文件，这里有点暴力了
        rm -rf "$PG_CONF"
        echo "delete postgresql.conf" >> "$LOG_FILE" 2>&1
        
        # 判断文件是否存在
        if [ -f "$PG_CONF_BAK" ]; then
            echo "$PG_CONF_BAK exists" >> "$LOG_FILE" 2>&1
            # 备份的conf存在，拷贝过来
            cp "$PG_CONF_BAK"  "$PG_DATA"
            echo "copy postgresql.conf" >> "$LOG_FILE" 2>&1
        else
            echo "$PG_CONF_BAK does not exists" >> "$LOG_FILE" 2>&1
            # 删除原来的data，有点暴力了
            rm -rf "$PG_DATA" >> "$LOG_FILE" 2>&1
            echo "delete $PG_DATA" >> "$LOG_FILE" 2>&1
            # initdb
            "$PG_INITDB" -D "$PG_DATA" >> "$LOG_FILE" 2>&1
            # 如果initdb错误，返回错误，退出
            if [[ $? -ne 0 ]]; then
                echo "Failed to initialize data directory, please check permissions or configuration." >> "$LOG_FILE" 2>&1
                rm -rf "$PG_DATA" >> "$LOG_FILE" 2>&1
                echo "delete $PG_DATA" >> "$LOG_FILE" 2>&1
                setprop persist.sys.ebase_start.error "$INITDB_ERROR"
                exit "$INITDB_ERROR"
            fi
            # 修改 unix_socket_directories,shared_buffers 和 maintenance_work_mem
            modify_or_add_parameter "unix_socket_directories" "'$PG_SOCKET_DIR'" "$PG_CONF"
            modify_or_add_parameter "shared_buffers" "128MB" "$PG_CONF"
            modify_or_add_parameter "maintenance_work_mem" "128MB" "$PG_CONF"

            # 将postgresql.conf拷贝一份到/data/ebase
            rm -rf "$PG_CONF_BAK" >> "$LOG_FILE" 2>&1 # 先删除一下
            cp "$PG_CONF" "$PG_EBASE"
            echo "Copied $PG_CONF to $PG_EBASE." >> "$LOG_FILE" 2>&1
        fi
        
        rm -rf /data/ebase/shmem
        echo "delete shmem" >> "$LOG_FILE" 2>&1
        touch /data/ebase/shmem
        chmod 666  /data/ebase/shmem
        echo "touch shmem" >> "$LOG_FILE" 2>&1
        # setprop persist.sys.ebase_start.error "$CONFIGURE_FILE_ERROR"
        # exit "$CONFIGURE_FILE_ERROR"
     #no space left
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

# 检查 pg_hba.conf 中是否配置为 md5
# 已经配置了，不需要做什么
# 没有配置，设置用户密码，配置一下md5，再重启
if grep -q "^host.*all.*all.*md5" "$PG_HBA"; then 
    echo "pg_hba.conf has been configured as md5." >> "$LOG_FILE" 2>&1
else
    echo "Change User Password..." >> "$LOG_FILE" 2>&1
    "$PG_PSQL" -U "$DB_USER" -d postgres -h "$PG_SOCKET_DIR" -c "ALTER USER $DB_USER PASSWORD '$DB_PASSWORD';" >> "$LOG_FILE" 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Failed to change user password, please check the database status." >> "$LOG_FILE" 2>&1
        # 这里已经启动，如果exit会导致进程被杀，是否需要添加一个stop
        "$PG_CTL" stop -D "$PG_DATA" > "$START_LOG_FILE" 2>&1
        echo "stop database" >> "$LOG_FILE" 2>&1
        setprop persist.sys.ebase_start.error "$EDIT_PASSWORT_ERROR"
        exit "$EDIT_PASSWORT_ERROR"
    fi

    echo "Configure pg_ hba.conf to md5"  >> "$LOG_FILE" 2>&1
    sed -i 's/trust/md5/g' "$PG_HBA"

    if grep -q "^host.*all.*all.*md5" "$PG_HBA";then
        echo "Successfully configured the pg_hba.conf!"  >> "$LOG_FILE" 2>&1
    else
        echo "Failed to configure the pg_hba.conf!"  >> "$LOG_FILE" 2>&1
    fi

    echo "Attempt to restart database..." >> "$LOG_FILE" 2>&1
    "$PG_CTL" restart -D "$PG_DATA" > "$START_LOG_FILE" 2>&1
    if [[ $? -ne 0 ]]; then
        echo "Restartup failed, please check the startlog file:$START_LOG_FILE" >> "$LOG_FILE" 2>&1
        setprop persist.sys.ebase_start.error "$RESTART_FAIL"
        exit "$RESTART_FAIL"
    fi
fi

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
