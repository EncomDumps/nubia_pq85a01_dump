#!/system/bin/sh

dumpsyspid=$(pidof dumpsys)
if [ -n "${dumpsyspid}" ] ; then exit 0; fi

if [ "x$(getprop persist.sys.ztelog.enable)" != "x1" ]; then
    exit 0
fi

trace_log_dir=/data/local/vendor_logs
cd ${trace_log_dir}/logcat/ || exit 0

# default part of output file name
num='0'
oom_num=$(getprop sys.lmk.oom_mark_victim)
if [ -n "${oom_num}" ]; then
    num=${oom_num}
fi

file_dumpsys_meminfo=dumpsys_meminfo_${num}.txt
dumpsys meminfo > "${file_dumpsys_meminfo}"

