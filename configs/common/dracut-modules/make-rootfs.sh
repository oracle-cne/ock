#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x

OSTREE_VAR_DIR=$(realpath /sysroot/$(cat /proc/cmdline | grep -o -e 'ostree=[a-zA-Z0-9/.]*' | grep -o '[a-zA-Z0-9/.]*$')/../../var)

mount --bind "$OSTREE_VAR_DIR" /sysroot/var

ls -l /sysroot
mount
mkdir -p /sysroot/var/home
mkdir -p /sysroot/var/ocne/cni/bin
mkdir -p /sysroot/var/ocne/cni/bin-workdir

setfiles -vFi0 -r /sysroot /sysroot/etc/selinux/targeted/contexts/files/file_contexts /sysroot/var

# Work around https://github.com/coreos/rpm-ostree/issues/29
grep -E '^wheel:' /sysroot/usr/lib/group >> /sysroot/etc/group
