#!/vendor/bin/sh

# This script is used to check qcom keybox

LD_LIBRARY_PATH=/vendor/lib64/hw /vendor/bin/KmInstallKeybox checkkeybox checkkeybox true true
if [ $? -ne 0 ]; then
    echo "check qcom keybox failed"
    setprop persist.vendor.sys.check_keybox 0
else
    echo "check qcom keybox success"
    setprop persist.vendor.sys.check_keybox 1
fi
