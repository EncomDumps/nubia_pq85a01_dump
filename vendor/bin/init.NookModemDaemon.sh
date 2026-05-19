#! /vendor/bin/sh

#
# Copyright (c) 2025 ZTE Corporation.
# All Rights Reserved.
# Confidential and Proprietary - ZTE Corporation.
#

# don't add spaces before or after the assignment operator '='
multisim=`getprop persist.radio.multisim.config`

while [ -z "$multisim" ]; do
    echo "failed to get multisim, waiting for it to be set"
    sleep 0.5
    multisim=`getprop persist.radio.multisim.config`
done

echo "persist.radio.multisim.config = $multisim"

# start 1st service instance for all projects
start NookModemDaemon_0

# start 2nd service instance only for dual-sim projects
if [ "$multisim" = "dsds" ] || [ "$multisim" = "dsda" ]; then
    start NookModemDaemon_1
fi
