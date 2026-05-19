#! /vendor/bin/sh

#
# Copyright (c) 2019 ZTE Corporation.
# All Rights Reserved.
# Confidential and Proprietary - ZTE Corporation.
#

# don't add spaces before or after the assignment operator '='
soc_vendor=`getprop ro.vendor.feature.soc_vendor`

while [ -z "$soc_vendor" ]; do
    echo "soc_vendor is empty, waiting for it to be set"
    sleep 0.5
    soc_vendor=`getprop ro.vendor.feature.soc_vendor`
done

# start different service per soc vendor
if [ "$soc_vendor" = "mediatek" ]; then
    start mtk-ssdaemon_vendor
elif [ "$soc_vendor" = "sprd" ]; then
    start sprd-ssdaemon_vendor
elif [ "$soc_vendor" = "qcom" ]; then
    start qti-ssdaemon_vendor
    start qti-msdaemon_vendor-0

    multisim=`getprop persist.radio.multisim.config`

    if [ "$multisim" = "dsds" ] || [ "$multisim" = "dsda" ]; then
        start qti-msdaemon_vendor-1
    fi
fi
