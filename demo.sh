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

function _get_stats {
    before=$(curl -s http://localhost:5001/status/format/json | jq '.upstreamZones["::nogroups"][0].outBytes')
    [[ $before == "null" ]] && before=0
    time kubectl rollout status deployment/java-server >/dev/null
    kubectl get pods -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq -c | sort -nr
    after=$(curl -s http://localhost:5001/status/format/json | jq '.upstreamZones["::nogroups"][0].outBytes')
    data_transf=$((after - before))
    info "Data Transfer: $(printf "%sB\nMB" "$data_transf" | units --quiet --one-line --compact)MB"
}

# Deploy initial version
info "Deploy initial version of java web server"
kubectl create deployment java-server --image localhost:5001/java-server:v1 --replicas 20
_get_stats

# Deploy distroless image
info "Upgrade the version of java web server"
kubectl set image deployments/java-server java-server=localhost:5001/java-server:v2
_get_stats
