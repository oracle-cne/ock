#! /bin/bash

/usr/bin/check-node-health.sh

if [ $? -ne 0 ]; then
	bash
else
	sudo cat /etc/kubernetes/admin.conf
fi
