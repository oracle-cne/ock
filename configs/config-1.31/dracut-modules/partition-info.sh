#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

# Do the level best to have a calm device tree.
udevadm trigger --settle

ROOT="$1"
ROOT_DEVICE=


# Get the block device that hosts the root partition.  Try a handful of
# times to allow for udev to freak out a bit and then recover.
i=0
while [ $i -le 20 ]; do
	if [ -L "${ROOT}" ]; then
		# Get the major:minor device id and then follow the
		# symlink over to its location in /sys/devices
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

# Get the partition number for the partition
PARTITION=$(cat "${ROOT_DEVICE}/partition")

# Get the major:minor device id of the block volume.
DISK_DEVICE_NUMBER=$(cat "${ROOT_DEVICE}/../dev")

DISK=

# Troll through the entries in /dev/ looking for the right
# device id.
for DEV in $(ls /dev); do
	if [ "${DISK_DEVICE_NUMBER}" = "$(stat -L -c '%t:%T' /dev/${DEV})" ]; then
		DISK="/dev/${DEV}"
		break
	fi
done

ROOT=$(realpath ${ROOT})

echo "${DISK} ${PARTITION} ${ROOT}"
