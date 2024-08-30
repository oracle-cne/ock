#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e

echo "Verifying images"
REGEX="exporting opaque data as blob.*sha256:([^\\]*).*Can't read link([^\\]*)"
ERR_FILE="/tmp/podman-corrupt-images.out"

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
