#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x
set -e


# If Kubernetes is already configured, don't bother doing anything
if [[ -f "/etc/kubernetes/kubelet.conf" ]]; then

	# If a static IP is in the configuration, assign it to a reasonable NIC
	# This is hardcoded to a libvirt interface for now as a demo
	# TODO fix this and configure it for real
	if [[ "$KUBE_APISERVER_IP" != "" ]]; then
		ip addr add $KUBE_APISERVER_IP/24 dev enp1s0 
	fi

	echo Kubernetes is already initialized
	exit 0
fi


# If a static IP is in the configuration, assign it to a reasonable NIC
# This is hardcoded to a libvirt interface for now as a demo
# TODO fix this and configure it for real
if [[ "$KUBE_APISERVER_IP" != "" ]]; then
	ip addr add $KUBE_APISERVER_IP/24 dev enp1s0 
fi


# This is a temporary hack to allow me to be lazy
# about configuring DHCP and DNS in libvirt
hostnamectl set-hostname "ocne$RANDOM"
#if [[ "$HOSTNAME" != "" ]]; then
#	hostnamectl set-hostname "$HOSTNAME"
#fi

K8S=/etc/kubernetes
PKI=$K8S/pki
CRIO=/etc/crio/

mkdir -p $K8S
mkdir -p $CRIO

if [[ "$ACTION" != "" ]]; then
	echo "${KUBEADM_CONFIG}" | base64 -d > ${K8S}/kubeadm.conf
	echo "${CRIO_CONFIG}" | base64 -d > ${CRIO}/crio.conf
fi

systemctl enable --now crio.service
systemctl enable kubelet.service

if [[ "$ACTION" == "" ]]; then
	kubeadm init --config /etc/ocne/kubeadm-default.conf
	KUBECONFIG=/etc/kubernetes/admin.conf kubectl taint node $(hostname)  node-role.kubernetes.io/control-plane:NoSchedule-
elif [[ "$ACTION" == "init" ]]; then
	echo Initalizing new Kubernetes cluster
	mkdir -p $PKI
	echo "${CA_KEY}" | base64 -d > ${PKI}/ca.key
	echo "${CA_CERT}" | base64 -d > ${PKI}/ca.crt

	kubeadm init --config ${K8S}/kubeadm.conf
elif [[ "$ACTION" == "join" ]]; then
	echo Joining existing Kubernetes cluster
	kubeadm join --config ${K8S}/kubeadm.conf
else
	echo "Action '$ACTION' is invalid.  Valid values are 'init' and 'join'"
	exit 1
fi
