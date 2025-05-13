#! /bin/bash
#
# Copyright (c) 2024, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x
set -e

if [[ -f "/etc/ocne/reset-kubeadm" ]]; then
        echo Performing kubeadm reset
        kubeadm reset -f && rm /etc/ocne/reset-kubeadm
fi

# If there is no network interface set, then pick something
# that could reasonably be considered the "default interface"
if [ -z "$NET_INTERFACE" ]; then
	NET_INTERFACE=$(route -n | grep '^0.0.0.0' | awk '{print $8}')
fi

NODE_IP=$(ip addr show "$NET_INTERFACE" | grep 'inet6\?\b' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

# If Kubernetes is already configured, don't bother doing anything
if [[ -f "/etc/kubernetes/kubelet.conf" ]]; then
        echo Kubernetes is already initialized
        exit 0
fi

K8S=/etc/kubernetes
PKI=$K8S/pki

# Assign a random hostname if there is not one defined.
# This allows clusters to start and join with unique
# names if DHCP does not assign hostnames or one is
# not statically configured.
if hostname | grep -q '^localhost\.'; then
	HN=ocne$RANDOM
	echo $HN > /etc/hostname
	hostname $HN
fi

systemctl enable --now crio.service
systemctl enable kubelet.service

# update kubeadm.conf to replace NODE_IP with $NODE_IP
sed -i -e 's/NODE_IP/'"$NODE_IP"'/g' ${K8S}/kubeadm.conf || true

if [[ "$ACTION" == "" ]]; then
        kubeadm init --config /etc/ocne/kubeadm-default.conf
        KUBECONFIG=/etc/kubernetes/admin.conf kubectl taint node $(hostname)  node-role.kubernetes.io/control-plane:NoSchedule-
elif [[ "$ACTION" == "init" ]]; then
        echo Initalizing new Kubernetes cluster
        mkdir -p $PKI

        kubeadm init --config ${K8S}/kubeadm.conf --upload-certs

        ENDPOINT=$(yq 'select(.kind == "ClusterConfiguration") | .controlPlaneEndpoint' < /etc/kubernetes/kubeadm.conf)
        ENDPOINT_IP=$(echo $ENDPOINT | cut -d: -f1)
        ENDPOINT_PORT=$(echo $ENDPOINT | cut -d: -f2)

elif [[ "$ACTION" == "join" ]]; then
        echo Joining existing Kubernetes cluster
        kubeadm join --config ${K8S}/kubeadm.conf
else
        echo "Action '$ACTION' is invalid.  Valid values are 'init' and 'join'"
        exit 1
fi

# keepalived track script user keepalived_script needs to read this file
if [ -f "/etc/kubernetes/admin.conf" ]; then
        cp /etc/kubernetes/admin.conf /etc/keepalived/kubeconfig
        chown keepalived_script:keepalived_script /etc/keepalived/kubeconfig
        chmod 400 /etc/keepalived/kubeconfig
fi
