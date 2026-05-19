#!/system/bin/sh

export LD_LIBRARY_PATH=/system_ext/lib64:$LD_LIBRARY_PATH
export PATH=/system_ext/bin:$PATH
export LD_PRELOAD=/system_ext/lib64/libandroid-shmem-aarch64-linux-androideabi26.so

echo "$(date '+%Y-%m-%d %H:%M:%S') stop ebase " >> /data/ebase/log 2>&1

./system_ext/bin/pg_ctl -D /data/ebase/data stop >> /data/ebase/log 2>&1

echo " " >> /data/ebase/log 2>&1

echo " " >> /data/ebase/log 2>&1
