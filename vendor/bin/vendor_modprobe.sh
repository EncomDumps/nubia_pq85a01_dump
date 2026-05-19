#! /vendor/bin/sh
#=============================================================================
# Copyright (c) 2019-2022 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#=============================================================================

VENDOR_DIR="/vendor/lib/modules"
VENDOR_DLKM_DIR="/vendor_dlkm/lib/modules"

MODPROBE="/vendor/bin/modprobe"

# vendor modules partition could be /vendor/lib/modules or /vendor_dlkm/lib/modules
POSSIBLE_DIRS="${VENDOR_DLKM_DIR} ${VENDOR_DIR}"
audio_arch=`getprop ro.boot.audio`

# Started by Cursor 10342497 20251225144703700
# Get product name and OEM key to determine which qca_cld3_peach module to load
product_name=`getprop ro.product.vendor.name`
oem_key1=`getprop ro.oem.key1`
PRODUCT_NAME_DEFERRED_PEACH="NX809J-UN"
# Ended by Cursor 10342497 20251225144703700

for dir in ${POSSIBLE_DIRS} ;
do
	if [ ! -e ${dir}/modules.load ]; then
		continue
	fi

	if [ "$audio_arch" == "audioreach" ]; then
		if [ -e ${dir}/modules.audio.ar.blocklist ]; then
			audio_blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.audio.ar.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
		fi
	else
		if [ -e ${dir}/modules.audio.legacy.blocklist ]; then
			audio_blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.audio.legacy.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
		fi
	fi

	# Use pattern if block list is empty so that all modules pass through grep below
	if [ "X${audio_blocklist_expr}" = "X" ]; then
		audio_blocklist_expr="-e %"
	fi

	if [ -e ${dir}/modules.blocklist ]; then
		blocklist_expr="$(sed -n -e 's/blocklist \(.*\)/\1/p' ${dir}/modules.blocklist | sed -e 's/-/_/g' -e 's/^/-e /')"
	fi

	# Use pattern if block list is empty so that all modules pass through grep below
	if [ "X${blocklist_expr}" = "X" ]; then
		blocklist_expr="-e %"
	fi

	# Filter out modules in blocklist - we would see unnecessary errors otherwise
	load_modules=$(sed = ${dir}/modules.load | sed 'N;s/\n/\t/' | sort -uk2 | sort -nk1 | cut -f2- | grep -w -v ${blocklist_expr} | grep -w -v ${audio_blocklist_expr})

	# Started by Cursor 10342497 20251225151246601
	# If oem_key1 ends with _JP, use qca_cld3_peach_v2_jp.ko, otherwise use regular ko
	if [ "$product_name" == "${PRODUCT_NAME_DEFERRED_PEACH}" ]; then
		if echo "${oem_key1}" | grep -q "_JP$"; then
			# oem_key1 ends with _JP, keep only qca_cld3_peach_v2_jp.ko
			load_modules=$(echo "${load_modules}" | grep -w -v "qca_cld3_peach_v2\.ko")
		else
			# oem_key1 does not end with _JP, keep only qca_cld3_peach_v2.ko
			load_modules=$(echo "${load_modules}" | grep -w -v "qca_cld3_peach_v2_jp\.ko")
		fi
	fi
	# Ended by Cursor 10342497 20251225151246601

	first_module=$(echo ${load_modules} | cut -d " " -f1)
	other_modules=$(echo ${load_modules} | cut -d " " -f2-)
	if ! ${MODPROBE} -b -s -d ${dir} -a ${first_module} > /dev/null ; then
		continue
	fi
	# load modules individually in case one of them fails to init
	for module in ${other_modules}; do
		( ${MODPROBE} -b -d ${dir} -a ${module} > /dev/null ) &
	done

	wait

	setprop vendor.all.modules.ready 1
	exit 0
done

exit 1
