#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x

# Run the appropriate form of "kubeadm upgrade" based on whether a control-plan or worker node
upgrade() {
  while true; do
    sleep 30s
    if ! KUBECONFIG=/etc/kubernetes/kubelet.conf kubectl get nodes; then
        echo API Server not available yet
        continue
    fi

    if KUBECONFIG=/etc/kubernetes/kubelet.conf kubectl get node $HOSTNAME --show-labels | grep -q "kubernetes.io/control-plane"; then
      # Upgrade the control-plane node
      kubeadm upgrade apply -y "$VERSION" --ignore-preflight-errors "CoreDNSUnsupportedPlugins,CoreDNSMigration,CreateJob" -v5
    else
      # Upgrade the worker node
      kubeadm upgrade node
    fi
    break
  done
}

# Determine if an kubeadm upgrade is required.
VERSION=$(kubeadm version -o yaml | yq eval .clientVersion.gitVersion | cut -d+ -f1)
VERSION_FILE=/var/ocne/kubeadm-version
mkdir -p "$(dirname $VERSION_FILE)"
if [ ! -f "$VERSION_FILE" ]; then
	echo "Version file does not exist yet, no upgrade required."
	echo "Noting current version as reference for future upgrades."
	echo "$VERSION" > "$VERSION_FILE"
	exit 0
fi

OLD_VERSION="$(< ${VERSION_FILE})"
OLDEST_VERSION=$(printf "%s\n%s" "${OLD_VERSION}" "${VERSION}" | sort -V | head -1)

# If the oldest version is not the same as the current version, then
# it is necessary to update
if [ "$OLDEST_VERSION" = "$VERSION" ]; then
	echo "Current version is the same as the previous version.  There is no upgrade to perform."
	exit 0
fi

upgrade
echo "$VERSION" > "$VERSION_FILE"
