#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

export KUBECONFIG=/etc/kubernetes/admin.conf

upgrade() {
	MD=/etc/kubernetes/manifests
	CATALOG=/usr/ock/catalog.yaml

	KAS="$(yq eval .kubeApiServer < $CATALOG)"
	KCM="$(yq eval .kubeControllerManager < $CATALOG)"
	KS="$(yq eval .kubeScheduler < $CATALOG)"
	E="$(yq eval .etcd < $CATALOG)"
	yq -i ".spec.containers[0].image = \"$KAS\"" "$MD/kube-apiserver.yaml"
	yq -i ".spec.containers[0].image = \"$KCM\"" "$MD/kube-controller-manager.yaml"
	yq -i ".spec.containers[0].image = \"$KS\"" "$MD/kube-scheduler.yaml"
	yq -i ".spec.containers[0].image = \"$E\"" "$MD/etcd.yaml"
	kubeadm certs renew all
}

# Write the current Kubernetes version to a known location.
# This is used later on in the script to determine if a
# "kubeadm upgrade" is required before starting kubelet.

# Output looks like this:
# sh-4.4# kubeadm version -o yaml
# clientVersion:
#   buildDate: "2023-04-11T16:10:50Z"
#   compiler: gc
#   gitCommit: 58d4f53b071abe2c1cc3b02008f3c81d9f4f09eb
#   gitTreeState: clean
#   gitVersion: v1.25.7+2.el8
#   goVersion: go1.19.4 X:boringcrypto
#   major: "1"
#   minor: "25"
#   platform: linux/amd64
#
# Out of that we need the gitVersion before the '+' character
VERSION=$(kubeadm version -o yaml | yq eval .clientVersion.gitVersion | cut -d+ -f1)

VERSION_FILE=/var/ocne/version
mkdir -p "$(dirname $VERSION_FILE)"

# If no kubeconfig for kubelet exists, it must not
# be initialized.  If it's not initialize, there
# is nothing to update.
if [ ! -f "$KUBECONFIG" ]; then
	echo "There is no update to perform."
	echo "Noting current version as reference for future updates."
	echo "$VERSION" > "$VERSION_FILE"
	exit 0
fi

# If the current version is the same as the previous version, don't bother updating
# There is a small chance that the version file doesn't exist yet.  If it doesn't,
# just set the old version to the current version and exit.
if [ ! -f "$VERSION_FILE" ]; then
	echo "Version file does not exist.  Noting current version as reference for future updates."
	echo "$VERSION" > "$VERSION_FILE"
	exit 0
fi

OLD_VERSION="$(< ${VERSION_FILE})"
OLDEST_VERSION=$(printf "${OLD_VERSION}\n${VERSION}" | sort -V | head -1)

# If the oldest version is not the same as the current version, then
# it is necessary to update
if [ "$OLDEST_VERSION" = "$VERSION" ]; then
	echo "Current version is the same as the previous version.  There is no update to perform."
	exit 0
fi

upgrade
echo "$VERSION" > "$VERSION_FILE"
