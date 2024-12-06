#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o pipefail
set -o errexit
set -o nounset
if [[ ${DEBUG:-false} == "true" ]]; then
    set -o xtrace
fi

source scripts/_utils.sh

# get_status() - Print the current status of the cluster
function get_status {
    set +o xtrace
    if [ -f /proc/stat ]; then
        printf "CPU usage: "
        grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage " %"}'
    fi
    if [ -f /proc/pressure/io ]; then
        printf "I/O Pressure Stall Information (PSI): "
        grep full /proc/pressure/io | awk '{ sub(/avg300=/, ""); print $4 }'
    fi
    printf "Memory free(Kb):"
    if [ -f /proc/zoneinfo ]; then
        awk -v low="$(grep low /proc/zoneinfo | awk '{k+=$2}END{print k}')" '{a[$1]=$2}  END{ print a["MemFree:"]+a["Active(file):"]+a["Inactive(file):"]+a["SReclaimable:"]-(12*low);}' /proc/meminfo
    fi
    printf "Disk usage: "
    sudo df -h
    if command -v docker >/dev/null; then
        echo "Docker statistics:"
        docker stats --no-stream
        docker ps --size
    fi

    echo "Kubernetes Events:"
    kubectl get events -A --sort-by=".metadata.managedFields[0].time"
    echo "Kubernetes Resources:"
    kubectl get all -A -o wide
    echo "Kubernetes Pods:"
    kubectl describe pods
    echo "Kubernetes Nodes:"
    kubectl describe nodes
}

function _get_stats {
    before=$(curl -s http://127.0.0.1:5001/status/format/json | jq '.upstreamZones["::nogroups"][0].outBytes')
    [[ $before == "null" ]] && before=0
    time kubectl rollout status deployment/java-server >/dev/null
    kubectl get pods -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c | sort -nr
    after=$(curl -s http://127.0.0.1:5001/status/format/json | jq '.upstreamZones["::nogroups"][0].outBytes')
    data_transf=$((after - before))
    info "Data Transfer: $(printf "%sB\nMB" "$data_transf" | units --quiet --one-line --compact)MB"
}

trap get_status ERR
trap 'kubectl delete deployments/java-server --ignore-not-found' EXIT

# Deploy initial version
info "Deploy version 1 of java web server"
kubectl create deployment java-server --image "$(sudo docker images --filter=reference='*/java-server:v1' --format "{{.Repository}}"):v1" --replicas 20
_get_stats

# Deploy distroless jdeps/jlink image
info "Upgrade java web server to version 2"
kubectl set image deployments/java-server java-server="$(sudo docker images --filter=reference='*/java-server:v2' --format "{{.Repository}}"):v2"
_get_stats

# Deploy distroless graalvm image
info "Upgrade java web server to version 3"
kubectl set image deployments/java-server java-server="$(sudo docker images --filter=reference='*/java-server:v2' --format "{{.Repository}}"):v3"
_get_stats
