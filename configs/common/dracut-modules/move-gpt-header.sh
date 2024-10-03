#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

udevadm trigger --settle

ROOT="/dev/disk/by-label/root"
ROOT_DEVICE=

i=0
while [ $i -le 20 ]; do
	if [ -L /dev/disk/by-label/root ]; then
		ROOT_DEVICE="$(realpath /sys/dev/block/$(stat -L -c '%t:%T' ${ROOT}))"
		break
	fi
	((i++)) || true
	sleep 1
done

if [ $i -eq 20 ]; then
	echo "Timed out waiting for root device"
	exit 1
fi

PARTITION=$(cat "${ROOT_DEVICE}/partition")
DISK_DEVICE_NUMBER=$(cat "${ROOT_DEVICE}/../dev")

DISK=

echo "root is $(ls -L ${ROOT})"

for DEV in $(ls /dev); do
	if [ "${DISK_DEVICE_NUMBER}" = "$(stat -L -c '%t:%T' /dev/${DEV})" ]; then
		DISK="/dev/${DEV}"
		break
	fi
done

sgdisk -e "${DISK}"
udevadm trigger --settle
