#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

udevadm trigger --settle

ROOT="/dev/disk/by-label/root"
ROOT_DEVICE="$(realpath /sys/dev/block/$(stat -L -c '%t:%T' ${ROOT}))"

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

mount "${ROOT}" /sysroot
growpart "${DISK}" "${PARTITION}" || true
xfs_growfs "${ROOT}"
