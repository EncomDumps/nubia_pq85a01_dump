#!/system/bin/sh
export PATH=/vendor/xbin:$PATH

if [ "$(getprop ro.vendor.feature.zte_feature_xproject)" != "true" ]; then
    echo "ro.vendor.feature.zte_feature_xproject is $(getprop ro.vendor.feature.zte_feature_xproject)"
    exit 0
fi

INTERVAL_MAIN=3600

function trim_tombstones()
{
    echo "trim_tombstones begin"
    TOMBSTONES_DIR="/data/tombstones"
    local tf
    local tt=`date +%G%m%d_%H%M%S`

    if [ ! -d $TOMBSTONES_DIR ]
    then
        echo "${TOMBSTONES_DIR} does not exist"
        return
    fi
    local curdir=`pwd`
    cd $TOMBSTONES_DIR
    local num=0
    local MAX_NUM=30
    for  tf in  $(ls -lt *tombstone* | awk '{print $8}')
    do
        echo "${tf}"
        let num=num+1
        if [ $num -gt $MAX_NUM ]
        then
            echo "rm ${tf}"
            rm ${tf}
        fi
    done

    cd $curdir
    echo "trim_tombstones end"
}

function trim_anrs()
{
    echo "trim_anrs begin"
    local curdir=`pwd`
    ANR_DIR="/data/anr"
    local tf
    local tt=`date +%G%m%d_%H%M%S`
    if [ ! -d $ANR_DIR]
    then
        echo "${ANR_DIR} does not exist"
        return
    fi

    cd $ANR_DIR
    local num=0
    local MAX_NUM=30
    for  tf in  $(ls -lt *anr* | awk '{print $8}')
    do
        echo "${tf}"
        let num=num+1
        if [ $num -gt $MAX_NUM ]
        then
            echo "rm ${tf}"
            rm ${tf}
        fi
    done

    local num=0
    local MAX_NUM=30
    for  tf in  $(ls -lt *trace* | awk '{print $8}')
    do
        echo "${tf}"
        let num=num+1
        if [ $num -gt $MAX_NUM ]
        then
            echo "rm ${tf}"
            rm ${tf}
        fi
    done

    cd $curdir
    echo "trim_anrs end"
}

function trim_xproject_dropbox()
{
    echo "trim_xproject_dropbox begin"
    DROPBOX_DIR="/data/local/xproject/dropbox"
    local tf
    local tt=`date +%G%m%d_%H%M%S`

    if [ ! -d $DROPBOX_DIR ]
    then
        echo "${DROPBOX_DIR} does not exist"
        return
    fi
    local curdir=`pwd`
    cd $DROPBOX_DIR
    local num=0
    local MAX_NUM=30
    for  tf in  $(ls -lt *.* | awk '{print $8}')
    do
        echo "${tf}"
        let num=num+1
        if [ $num -gt $MAX_NUM ]
        then
            echo "rm ${tf}"
            rm ${tf}
        fi
    done

    cd $curdir
    echo "trim_xproject_dropbox end"
}

function trim_xproject_tombstones()
{
    echo "trim_xproject_tombstones begin"
    TOMBSTONES_DIR="/data/local/xproject/tombstones"
    local tf
    local tt=`date +%G%m%d_%H%M%S`

    if [ ! -d $TOMBSTONES_DIR ]
    then
        echo "${TOMBSTONES_DIR} does not exist"
        return
    fi
    local curdir=`pwd`
    cd $TOMBSTONES_DIR
    local num=0
    local MAX_NUM=30
    for  tf in  $(ls -lt *tombstone* | awk '{print $8}')
    do
        echo "${tf}"
        let num=num+1
        if [ $num -gt $MAX_NUM ]
        then
            echo "rm ${tf}"
            rm ${tf}
        fi
    done

    cd $curdir
    echo "trim_xproject_tombstones end"
}

every60m=(0 3599 trim_tombstones trim_anrs trim_xproject_dropbox trim_xproject_tombstones)

crontab=(every60m)

function mainloop()
{
    echo "mainloop begin"
    local interval=0
    local e
    local next

    #process_info
    for e in ${crontab[@]}
    do
        eval next=\${${e}[0]}
        eval interval=\${${e}[1]}
        echo "cur:$e $next $interval $sys_uptime"
        if [ "$sys_uptime" -ge "$next" ] ;then
            interval=`expr $interval + $sys_uptime`
            eval ${e}[0]=\$interval
            eval next=\${${e}[0]}
            echo "next:$next $interval $sys_uptime"
            eval local len=\${#${e}[@]}
            local funi=2
            while [ $funi -lt $len ]
            do
                eval \${${e}[$funi]}
                eval echo \${${e}[$funi]}
                funi=`expr $funi + 1`
            done
        fi
    done
    echo "mainloop end"
}

while true
do

    if [ "$(getprop persist.sys.stc)" == "true" ]; then
        echo "persist.sys.stc is $(getprop persist.sys.stc)"
        exit 0
    fi

    uptime0=`cat /proc/uptime | sed 's/[\t ][\t ]*/\n/g' | sed -n '1p'`
    uptime0=${uptime0/\.*/}

    echo "time: $sys_uptime"
    mainloop
    uptime1=`cat /proc/uptime | sed 's/[\t ][\t ]*/\n/g' | sed -n '1p'`
    uptime1=${uptime1/\.*/}
    sec=`expr $uptime0 + $INTERVAL_MAIN - $uptime1`

    if [ -z "$sec" ]; then
        sec=$INTERVAL_MAIN
    fi

    if [ "$sec" -gt "3600" -o  "$sec" -le "0" ]; then
        echo "sec error $sec, reset it"
        sec=$INTERVAL_MAIN
    fi

    echo "need to sleep $sec"
    sleep $sec
    sys_uptime=`expr $sys_uptime + $INTERVAL_MAIN`
done
