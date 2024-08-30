#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Reset Kubernetes
kubeadm reset -f

# stop cri-o
systemctl stop crio.service

# Clean CNI

# Restart ocne.service
systemctl restart ocne.service
