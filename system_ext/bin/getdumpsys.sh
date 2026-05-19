#!/system/bin/sh

trace_log_dir=/data/local/vendor_logs
if [ "x$(getprop persist.sys.ztelog.enable)" != "x1" ]; then
    exit 0
fi

local isrunning=`getprop debug.systrace.running`
if [ "x${isrunning}" = "x1" ]; then
    echo "systrace is running"
    exit 0
fi

local reason=$(getprop debug.systrace.reason)
local jank=$(getprop init.svc.jankdumpsystrace)
if [ "$jank" = "running" ] ; then
        reason="jank"
fi
local trim_reason=${reason/\//\.}

cd ${trace_log_dir}/logcat/ || exit

#
# add for display dumpsys
#
if [ ! -n "$trim_reason" ]; then
    local file_name=dumpsys_screenshot_$(date +%G%m%d_%H%M%S).txt

    echo "begin time: "$(date +%G%m%d_%T.%N) >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys user" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 user -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys window" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 window -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys GameAssistService" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity service GameAssistService >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys FanService" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity service FanService >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys OMTService" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity service OMTService >> $file_name
    echo "        dumpsys KeyMapCenterService" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity service KeyMapCenterService >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys GameHandleService" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity service GameHandleService >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys MoonLightService" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity service MoonLightService >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys display" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 display -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys power" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 power -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys uimode" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 uimode -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys input" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 input -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys input_method" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 input_method -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys SurfaceFlinger" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 SurfaceFlinger -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys activity recents" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity recents >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys account accounts" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 account accounts >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys activity broadcasts" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity broadcasts >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys activity activities" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity activities >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys activity service SystemUIService" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity service SystemUIService >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys alarm" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 alarm -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys jobscheduler" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 jobscheduler -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys notification" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 notification -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys audio" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 audio -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys audioflinger" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 media.audio_flinger -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys audiopolicy" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 media.audio_policy -a >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys sensorservice" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 sensorservice >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys meminfo" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 meminfo -S >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys activity activities" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 activity activities >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dumpsys SurfaceFlinger fpsControl" >> $file_name
    echo "----------------------------------------" >> $file_name
    dumpsys -t 30 SurfaceFlinger --fpsControl >> $file_name
    echo "----------------------------------------" >> $file_name
    echo "        dmabuf_dump                     " >> $file_name
    echo "----------------------------------------" >> $file_name
    dmabuf_dump >> $file_name

    if [ $(whoami) = "root" ];then
        temp=$(date +%G%m%d_%T)
        temp=$(echo "$temp" | sed 's/:/-/g')
        iptabledir="data/netcontrol_${temp}"
        mkdir -p "$iptabledir"

        iptables -nvL  > "${iptabledir}/iptables-filter.txt"
        iptables-save > "${iptabledir}/iptables-save.txt"
        ifconfig > "${iptabledir}/ifconfig.txt"
        ip rule > "${iptabledir}/iprule.txt"
        ip route > "${iptabledir}/iproute.txt"

        {
                echo "dumpsys connectivity  trafficcontroller"
                echo "----------------------------------------"
                dumpsys -t 30 connectivity  trafficcontroller
        } > "${iptabledir}/trafficcontroller.txt"

        ss -tpaen -o state established > "${iptabledir}/ss.txt"
    fi

    echo "end time: "$(date +%G%m%d_%T.%N) >> $file_name
    chmod 755 $file_name

    # clear old file begin
    local num=0
    local filelimit=5
    for file in `ls dumpsys_screenshot*.txt | sort -nr`
    do
        num=`expr $num + 1`
        echo $num
        if [ "$num" -gt $filelimit ]; then
            rm -rf $file
        echo $file
        fi
    done
    # clear old file end

    # get cpu irq info begin
    cat /proc/interrupts > cpu_irq_info.txt
    # get cpu irq info end

    # get scenedecision info
    dumpsys scenedecision -appInfoTable > ${trace_log_dir}/logcat/dump_appInfoTable.csv
    dumpsys scenedecision -appSettingsTable > ${trace_log_dir}/logcat/dump_appSettingsTable.csv

    cp /data/system/app_run_info ${trace_log_dir}/logcat/app_run_info.txt
fi
