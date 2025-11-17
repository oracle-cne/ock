#! /bin/bash
#
# Copyright (c) 2024, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# Image is set via drop-in to OCNE_OS_IMAGE
ARCH=`uname -m`
OSTREE_REPO=/sysroot/ostree/repo

if [ -z "$OCNE_UPDATE_CONFIG" ]; then
	OCNE_UPDATE_CONFIG=/etc/ocne/update.yaml
fi

OCNE_OS_REGISTRY=$(yq -r '.registry // ""' < "$OCNE_UPDATE_CONFIG")
OCNE_OS_TAG=$(yq -r '.tag // ""' < "$OCNE_UPDATE_CONFIG")
OSTREE_TRANSPORT=$(yq -r '.transport // ""' < "$OCNE_UPDATE_CONFIG")

if [ -z "$OCNE_OS_REGISTRY" ]; then
	# TODO point this somewhere reasonable
	OCNE_OS_REGISTRY=container-registry.oracle.com/olcne/ock
fi
if [ -z "$OCNE_OS_TAG" ]; then
	# TODO make this reasonable
	OCNE_OS_TAG=latest
fi
if [ -z "$OSTREE_TRANSPORT" ]; then
	# TODO this is a bad default
	OSTREE_TRANSPORT=ostree-unverified-registry
fi

OCNE_OS_IMAGE="$OCNE_OS_REGISTRY:$OCNE_OS_TAG"

case "$ARCH" in
	x86_64 ) ARCH=amd64 ;;
	aarch64 ) ARCH=arm64 ;;
	* ) echo "Architecture $ARCH is not supported"; exit 1 ;;
esac

# Get the Skopeo transport from the ostree transport
SKOPEO_TRANSPORT=
OCNE_OS_IMAGE="$OCNE_OS_REGISTRY"
case "$OSTREE_TRANSPORT" in
	*docker:// )
		SKOPEO_TRANSPORT="docker://" ;;
	ostree-unverified-image:*  | ostree-image-signed:* )
		SKOPEO_TRANSPORT="$(echo "$OSTREE_TRANSPORT" | cut -d: -f2-):"
		OSTREE_TRANSPORT="$OSTREE_TRANSPORT:"
		;;
	ostree-unverified-registry )
		SKOPEO_TRANSPORT="docker://"
		OSTREE_TRANSPORT="$OSTREE_TRANSPORT:"
		;;
	ostree-remote-image:*:* | ostree-remote-registry:*:* )
		SKOPEO_TRANSPORT="$(echo "$OSTREE_TRANSPORT" | cut -d: -f3-):"
		OSTREE_TRANSPORT="$OSTREE_TRANSPORT:"
		;;
	*) echo "Invalid ostree transport: $OSTREE_TRANSPORT"; exit 1 ;;
esac

# Add the tag if necessary
case "$SKOPEO_TRANSPORT" in
	containers-storage* | docker:// | docker-* | ostree* )
		OCNE_OS_IMAGE="$OCNE_OS_IMAGE:$OCNE_OS_TAG" ;;
	*)
		;;
esac

# Use the kubelet kubeconfig as the credentials for talking to
# the cluster.  They are guaranteed to be there if the node
# can be annotated.
export KUBECONFIG=/etc/kubernetes/kubelet.conf

# Check for updates and if an update is available, apply it to the ostree
update() {
	# Inspect the ostree image to get the manifest
	MANIFEST=$(skopeo inspect "$SKOPEO_TRANSPORT$OCNE_OS_IMAGE")

	if [ $? -ne 0 ]; then
		echo Could not inspect image: "$OCNE_OS_IMAGE"
		return
	fi

	if [[ -z "$MANIFEST" ]]; then
		# Image not found
		echo Image not found: "$OCNE_OS_IMAGE"
		return
	fi

	NEW_IMAGE_DIGEST=$(echo "$MANIFEST" | jq -r '.Digest')

	if [[ "$IMAGE_DIGEST" == "$NEW_IMAGE_DIGEST" ]]; then
		echo ostree image has not changed. Trying again later.
		return
	fi

	# IMAGE_DIGEST is either empty or the digests do not match, check to see if
	# the commit is already present
	echo Checking for new content
	NEW_OSTREE_COMMIT=$(echo "$MANIFEST" | jq -r '.Labels["ostree.commit"]')
	echo Image has ostree commit label: $NEW_OSTREE_COMMIT

	ostree log $NEW_OSTREE_COMMIT
	if [ $? -eq 0 ]; then
		echo ostree commit already exists. Trying again later.
		IMAGE_DIGEST=$NEW_IMAGE_DIGEST
		return
	fi

	# Rebase to the ostree image, this will pull the image, unencapsulate the ostree, and commit
	echo Unencapsulating image
	rpm-ostree rebase --experimental --os=ock --download-only "$OSTREE_TRANSPORT$OCNE_OS_IMAGE"
	if [ $? -ne 0 ]; then
		echo Could not unencapsulate updated image
		return
	fi

	# Overwrite the ock:ock ref with the commit we just applied - this just
	# makes it easier to deal with the ref so we don't have to refer to the ugly generated one
	ostree refs $NEW_OSTREE_COMMIT --create=ock:ock --force
	if [ $? -ne 0 ]; then
		echo Could not overwrite ostree ref
		return
	fi

	# If the kubeconfig is not present, the there is not a node
	# to annotate.  Skip that step for now.
	#
	# There is likely a race condition here.  If the cluster is
	# coming up and an update is available, it is possible to
	# process the update before the cluster is up.  In that case,
	# the update annotation will not happen.
	#
	# Revisit this when a production implementation is required.
	if [ ! -f "$KUBECONFIG" ]; then
		echo Kubelet kubeconfig does not exist.  Skipping annotation.
		return
	fi

	# After the new version is pulled and extracted, mark the node as
	# to indicate as such.  This is done after the extraction to make
	# sure that the node can actually be updated if it is marked.
	#NODE_NAME=$(yq -r '.users[0].name' < "$KUBECONFIG" | cut -d: -f 3)
	NODE_NAME=$(hostname)
	kubectl annotate node "$NODE_NAME" ocne.oracle.com/update-available=true

	# Success! Save the digest so we can compare the next time through the loop
	IMAGE_DIGEST=$NEW_IMAGE_DIGEST
}

# Loop forever, checking for and applying updates as needed
while true; do
	update
	sleep 2m
done
