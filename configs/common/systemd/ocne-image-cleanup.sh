#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

echo "Verifying images"
REGEX="exporting opaque data as blob.*sha256:([^\\]*).*Can't read link([^\\]*)"
ERR_FILE="/tmp/podman-corrupt-images.out"

# Clean up tags in the r/w cache that refer to r/o images that
# no longer exist
K="container-registry.oracle.com/olcne/kube-proxy"
C="container-registry.oracle.com/olcne/coredns"
F='{{.Repository}}:{{.Tag}}'
ls -l /var/lib/containers/storage
podman images
BAD_TAGS=$(podman images 2>&1 1>/dev/null | sed 's/.* of image \([a-z0-9]*\) not found .*/\1/p' | sort | uniq)
for bad in $BAD_TAGS; do
  podman rmi -f "$bad"
done
KPC=$(podman images --format "$F" --filter "reference=$K:current")
if [ -z "$KPC" ]; then
  KP=$(podman images --format "$F" --filter "reference=$K" --sort created | head -1)
  podman tag "$KP" "$K:current"
fi
CDC=$(podman images --format "$F" --filter "reference=$C:current")
if [ -z "$CDC" ]; then
  CD=$(podman images --format "$F" --filter "reference=$C" --sort created | head -1)
  podman tag "$CD" "$C:current"
fi

# Clean up r/w images that have layers in the r/w cache with lower
# layers in the r/o cache that no longer exist.
while true;
do
  # first check if there are any corrupt images
  rm -f $ERR_FILE
  podman images --format '{{.Id}}' | xargs -i sh -c 'podman inspect {} || true ' > /dev/null 2> $ERR_FILE
  if [ -s $ERR_FILE ]; then
    # there is at least 1 corrupt image.  Now run the same command with debug so we can get the image id
    podman images --format '{{.Id}}' | xargs -i sh -c 'podman inspect  --log-level=debug {} || true ' > /dev/null 2> $ERR_FILE

    # use regex to get the image id from the error file
    data="$(cat $ERR_FILE)"
    if [[ $data =~ $REGEX ]]; then
      ID="${BASH_REMATCH[1]}"
      echo "Deleting Image with ID $ID"
      podman rmi $ID --force
    fi
  else
    echo "Finished verifying images"
    rm -f $ERR_FILE
    exit 0
  fi
done
