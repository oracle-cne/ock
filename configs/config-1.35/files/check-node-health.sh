#!/bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

kubelet_status_exit_code=1

# Get the kubelet status
get_kubelet_status() {
    systemctl status kubelet &> /dev/null
    kubelet_status_exit_code=$?
}

# Display kubelet status using systemctl
display_kubelet_status() {
    printf "\n"
    get_kubelet_status
  
  if [[ $kubelet_status_exit_code -eq 0 ]]; then
    echo "Kubelet Status: Running"
  else
    echo "Kubelet Status: Not Running"
  fi
}

# Display node disk and memory information
display_node_info() {
    printf "\n"
    free -h | grep 'Mem:' | awk '{print "Memory Usage: " $3 "/" $2}'
    printf "\n"
    echo "Disk Usage:"
    df -h
}

main() {

    get_kubelet_status
    if [ $kubelet_status_exit_code -ne 0 ]; then
        echo -e "Node Information:"
        display_kubelet_status
        display_node_info
    fi 
}

main
exit $kubelet_status_exit_code
