#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

/usr/bin/check-node-health.sh

if [ $? -ne 0 ]; then
	bash
else
	sudo cat /etc/kubernetes/admin.conf
fi
