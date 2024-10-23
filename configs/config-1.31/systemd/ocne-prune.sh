#!/bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# This script prunes the ostree to remove commits that are no longer reachable. This
# frees disk space and keeps the ostree tidy.

if [ -z "$OCNE_PRUNE_CONFIG" ]; then
	OCNE_PRUNE_CONFIG=/etc/ocne/prune.yaml
fi

# This setting seems to allow you to keep recent commits even if they are no longer
# reachable, but testing produces unexpected behavior, so I am not entirely sure
# what this does.
KEEP_YOUNGER_THAN=$(yq -r '.keepYoungerThan // ""' < "$OCNE_PRUNE_CONFIG")

if [ -z "$KEEP_YOUNGER_THAN" ]; then
	KEEP_YOUNGER_THAN="6 months ago"
fi

echo Pruning ostree
set -x
ostree prune --refs-only --keep-younger-than="$KEEP_YOUNGER_THAN"
