#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

depends() {
	echo ignition
}

install() {
	inst_multiple \
		xfs_growfs \
		growpart \
		stat \
		awk \
		blkid \
		sgdisk \
		sfdisk \
		partx \
		flock \
		sed \
		realpath

	inst_script "$moddir/grow-rootfs.sh" /usr/sbin/grow-rootfs
	inst_script "$moddir/make-rootfs.sh" /usr/sbin/make-rootfs
	inst_script "$moddir/move-gpt-header.sh" /usr/sbin/move-gpt-header
	inst_simple "$moddir/grow-rootfs.service" "$systemdsystemunitdir/grow-rootfs.service"
	inst_simple "$moddir/make-rootfs.service" "$systemdsystemunitdir/make-rootfs.service"
	inst_simple "$moddir/move-gpt-header.service" "$systemdsystemunitdir/move-gpt-header.service"

	systemctl -q --root="$initdir" add-requires "ignition-complete.target" grow-rootfs.service
	systemctl -q --root="$initdir" add-requires "ignition-complete.target" make-rootfs.service
	systemctl -q --root="$initdir" add-requires "ignition-complete.target" move-gpt-header.service
}
