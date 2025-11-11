#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

# Try to find the device that holds the root filesystem, if one exists.
# If one does not exist, exit with success.  It is possible that the root
# partition is not yet available for some reason.
ROOT="/dev/disk/by-label/root"
DEVICES=
if ! DEVICES=$(/usr/sbin/partition-info "${ROOT}"); then
	echo "Root disk does not exist"
	exit 0
fi

read -r -a ROOT_DEVICES <<< "$DEVICES"
DISK="${ROOT_DEVICES[0]}"
PARTITION="${ROOT_DEVICES[1]}"
ROOT="${ROOT_DEVICES[2]}"

# Expand the parition and the filesystem on that partition
mount "${ROOT}" /sysroot
growpart "${DISK}" "${PARTITION}" || true
xfs_growfs "${ROOT}"
