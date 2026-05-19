#!/system/bin/sh
insmod /vendor/lib/modules/qca_cld3_peach_v2.ko con_mode=5
sleep 1
TIMEOUT_SECONDS=15
SLEEP_INTERVAL=1
WLAN0_FOUND=false
for i in $(seq 1 ${TIMEOUT_SECONDS}); do
    toybox ifconfig wlan0 | toybox grep "wlan0"
    if [ $? -eq 0 ]; then
        WLAN0_FOUND=true
        break
    else
        sleep ${SLEEP_INTERVAL}
    fi
done

if [ "${WLAN0_FOUND}" = "true" ]; then
    echo true
else
    echo false
fi
sleep 1
rmmod qca_cld3_peach_v2
