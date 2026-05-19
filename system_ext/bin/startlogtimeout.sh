#!/system/bin/sh

trace_log_dir=/data/local/vendor_logs
if [ "x$(getprop persist.sys.ztelog.enable)" != "x1" ]; then
    exit 0
fi

echo "----------------------------------------" >> ${trace_log_dir}/logcat/freezelog.txt
local tt=`date +%G%m%d_%H%M%S`
echo "dumpsys time: $tt" >> ${trace_log_dir}/logcat/freezelog.txt

for file in `find /sys/fs/cgroup -name cgroup.freeze`
do
    freeze=`cat $file`
    echo "$file    $freeze" >> ${trace_log_dir}/logcat/freezelog.txt
done

setprop persist.sys.logfortimeout 0