#!/system/bin/sh

# zte avoid dup atrace2 or perfetto running, -n for not null or exist
atrace2pid=`pidof atrace2`
if [ -n "$atrace2pid" ] ; then exit 0; fi

trace_log_dir=/data/local/vendor_logs

# add for xproject
xproject_trace_log_dir=/data/local/xproject/systrace
if [ "x$(getprop persist.sys.ztelog.enable)" != "x1" ]; then
    if [ "x$(getprop persist.sys.systrace.enable)" != "x1" ]; then # add for xproject
        if [ "x$(getprop persist.sys.xproject_systrace.enable)" != "x1" ]; then
            exit 0
        fi
    fi
fi


local isrunning=`getprop debug.systrace.running`
if [ "x${isrunning}" = "x1" ]; then
    echo "systrace is running"
    exit 0
fi

# zte add state for using perfetto instead of systrace, the latter is default case
use_atrace2_str="1"
if [ "x$(getprop persist.sys.atrace.perfetto_overrided)" = "x1" ]; then
    use_atrace2_str="0"
fi

#add by 10292412 for TP test
if [ -f "/.home" ] ; then
    /system/bin/get_tp_noise&
fi

if [ ! -f "/.cell" ] ; then
    /system/bin/get_tp_noise&
fi

MemTotalStr=`cat /proc/meminfo | /system/bin/grep MemTotal`
MemTotal=${MemTotalStr:16:8}
if [ $MemTotal -lt 800000 ]; then
    echo "dumptracer.sh exit becasue MemTotal = $MemTotal"
    exit 0
fi

# only do when use atrace2
if [ "x${use_atrace2_str}" = "x1" ]; then
    systracing_is_running=$(cat /sys/kernel/tracing/tracing_on)
    if [ "$systracing_is_running" -eq "0" ]; then
        echo "trace off and reopening ..."
        start atrace2 &
        # enough time to wait trace reopen then
        sleep 6
        echo "trace should be reopened"
        exit 0
    fi
fi

local reason=`getprop debug.systrace.reason`

local jank=`getprop init.svc.jankdumpsystrace`
if [ "$jank" = "running" ] ; then
        reason="jank"
fi

local tt=$(date +%Y%m%d_%H%M%S)
local trim_reason=${reason/\//\.}

#begin modify for xproject
local trace_file_name
if [[ $trim_reason == *"XFiles_SystraceFilter"* ]]; then
    trace_file_name="${trim_reason}.txt"
else
    trace_file_name="systrace.${tt}.${trim_reason}.txt"
fi
#end modify for xproject

#begin add for xproject
local xproject_systrace_only=0
if [[ $trim_reason == *"XFiles_SystraceFilter"* ]]; then
    if [ "x$(getprop persist.sys.ztelog.enable)" != "x1" ]; then
        if [ "x$(getprop persist.sys.xproject_systrace.enable)" = "x1" ]; then
            xproject_systrace_only=1
        fi
    fi
fi

if [ "x${xproject_systrace_only}" = "x1" ]; then
    trace_log_dir=/data/local/xproject/systrace
fi
#end add for xproject

if [ "$trim_reason" = "Healthy_Game" ] ; then
    trace_file_name=`getprop debug.systrace.filename`
    trace_log_dir=/data/nubiahealth/trace
    if [ ! -d ${trace_log_dir}/logcat ]; then
        mkdir ${trace_log_dir}/logcat
        chown system.root ${trace_log_dir}/logcat/
        chmod 777 ${trace_log_dir}/logcat/
    fi
fi

local file=${trace_log_dir}/logcat/$trace_file_name
cd ${trace_log_dir}/logcat/

#begin add for xproject
if [[ $trim_reason == *"XFiles_SystraceFilter"* ]]; then
    if [ "x${xproject_systrace_only}" = "x1" ]; then
        file=${trace_log_dir}/$trace_file_name
        cd ${trace_log_dir}
    fi
fi
#end add for xproject

#getenforce|grep Enforcing

#if $busybox [ $? -eq 0 ]; then
#    echo "enforceing..."
#cat /sys/kernel/tracing/trace > $file
#else
#    atrace -c -b 8192 -t 3600000 gfx wm view webview mdss am res app sched freq dalvik input message binder action memreclaim --async_dump -z -o $file
#fi

setprop debug.systrace.running "1"

if [ "x${use_atrace2_str}" = "x1" ]; then
    time=$(date "+%T.%N")
    echo "B|0000|***systrace dump timestamp is $time***" > /sys/kernel/tracing/trace_marker

    # zte systrace, stop tracing and app tags then get systrace, the trace data will be lost during this period
    echo 0 > /sys/kernel/tracing/tracing_on
    bak_tags=$(getprop debug.atrace.tags.enableflags)
    setprop debug.atrace.tags.enableflags 0
    atrace2 --async_dump -z -o "${file}" -m 3072000
    setprop debug.atrace.tags.enableflags "${bak_tags}"
    echo 1 > /sys/kernel/tracing/tracing_on
else
    if [ "x$(getprop debug.atrace.user_initiated)" = "x1" ]; then
        atrace2 --async_stop
        # wait enough for user initiated to empty
        sleep 8
        # not expected got data to output file
        # perfetto --txt --config /data/misc/perfetto-configs/perfetto_bugreport.cfg --out /data/misc/perfetto-traces/trace_null.tmp
        start perfetto_trace_configure &
        # skipped this time get trace data
    else
        perfetto2pid=$(pidof perfetto)
        if [ -n "$perfetto2pid" ] ; then
            # exist then try to get data
            perfetto --save-for-bugreport
            # cp "/data/misc/perfetto-traces/systrace.tmp" "${file}"
            cp "/data/misc/perfetto-traces/bugreport/systrace.pftrace" "${file}"

            chmod 755 "${file}"

            sleep 2
            tar cfz "${trace_file_name}.tar.gz" "${trace_file_name}"
            rm "${file}"

            chmod 755 "${trace_file_name}.tar.gz"
            #begin add for xproject
            if [[ $trim_reason == *"XFiles_SystraceFilter"* ]]; then
                if [ "x${xproject_systrace_only}" != "x1" ]; then
                    cp "${trace_file_name}.tar.gz" "${xproject_trace_log_dir}/"
                fi
                chown system:system "${xproject_trace_log_dir}/${trace_file_name}.tar.gz"
            fi
            #end add for xproject

            perfetto2pid=$(pidof perfetto)
            # expected after save bugreport
            if [ -z "$perfetto2pid" ] ; then
                start perfetto_trace_configure &
            fi
        else
            # not expected, just try to start again
            start perfetto_trace_configure &
        fi
    fi
fi


mkdir /sdcard/systrace/

trace_threshold=$(getprop persist.backtrace.threshold)
funi=0
local filelimit=5
if [ "$trim_reason" = "Healthy_Game" ] ; then
    filelimit=50
fi
for file in `ls ${trace_log_dir}/logcat/systrace* 2>/dev/null| sort -nr`
do
    funi=`expr $funi + 1`
    if [ "$funi" -gt $filelimit ]; then
        if [ "x${trace_threshold}" != "x" ]; then
            mv "$file" /sdcard/systrace/
        fi
        rm -fr "$file"
        echo "$file"
    fi
done

funi=0
for file in `ls /sdcard/systrace/systrace* 2>/dev/null| sort -nr`
do
funi=`expr $funi + 1`
if [ "$funi" -gt ${trace_threshold} ]; then
  rm -fr "$file"
  echo "$file"
fi
done

#begin add for xproject
funi=0
if [[ $trim_reason == *"XFiles_SystraceFilter"* ]]; then
    filelimit=50
    for file in `ls ${xproject_trace_log_dir}/systrace* 2>/dev/null| sort -nr`
    do
        funi=`expr $funi + 1`
        if [ "$funi" -gt "${filelimit}" ]; then
            rm -fr "$file"
            echo "$file"
        fi
    done
fi
#end add for xproject

#add by 10292412 for TP test
funi=0
for file in `ls /data/local/vendor_logs/logcat/tprawdata/get_noisedata*.txt | sort -nr`
do
funi=`expr $funi + 1`
if [ "$funi" -gt "60" ]; then
  rm -fr $file
  echo $file
fi
done

if [ "$trim_reason" = "Healthy_Game" ] ; then
    setprop debug.systrace.filename ""
fi
setprop debug.systrace.reason ""
setprop debug.systrace.running "0"
