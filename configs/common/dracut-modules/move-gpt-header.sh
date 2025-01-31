#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

ROOT=."/dev/disk/by-label/root"
DEVICES=$(/usr/sbin/partition-info "${ROOT}")

read -r -a ROOT_DEVICES <<< "$DEVICES"
DISK="${ROOT_DEVICES[0]}"

# Move the GPT header to the end of the disk
sgdisk -e "${DISK}"
udevadm trigger
udevadm settle
