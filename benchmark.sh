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

function _setup_sysctl {
    local key="$1"
    local value="$2"

    if [ "$(sysctl -n "$key")" != "$value" ]; then
        if [ -d /etc/sysctl.d ]; then
            echo "$key=$value" | sudo tee "/etc/sysctl.d/99-$key.conf"
        elif [ -f /etc/sysctl.conf ]; then
            echo "$key=$value" | sudo tee --append /etc/sysctl.conf
        fi

        sudo sysctl "$key=$value"
    fi
}

# Install requeriments
echo "::group::Install requriments"
if ! command -v docker >/dev/null; then
    export PKG="docker"
fi
# NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
curl -fsSL http://bit.ly/install_pkg | PKG_COMMANDS_LIST="jq" bash

if ! command -v nerdctl >/dev/null; then
    curl -s "https://i.jpillora.com/containerd/nerdctl!" | bash
fi

[ ! -d /opt/hello-bench ] && sudo git clone https://github.com/electrocucaracha/hello-bench/ /opt/hello-bench

_setup_sysctl "vm.max_map_count" "262144"
echo "::endgroup::"

# Get the metrics
echo "::group::Get metrics"
sudo /opt/hello-bench/hello.py --engine docker --op run --images python:3 alpine:3 ubuntu:20.04 ubuntu:22.04 >/dev/null
echo "::endgroup::"

# Display the metrics
while IFS= read -r line; do
    repo=$(echo "$line" | jq -r '.bench')
    pull=$(echo "$line" | jq '[ with_entries(select(.key | startswith("pull_elapsed", "total_elapsed"))) | .[] | tonumber ] | sort | (.[0]/.[1])*100 | .*100 | round/100')
    create=$(echo "$line" | jq '[ with_entries(select(.key | startswith("create_elapsed", "total_elapsed"))) | .[] | tonumber ] | sort | (.[0]/.[1])*100 | .*100 | round/100')
    run=$(echo "$line" | jq '[ with_entries(select(.key | startswith("run_elapsed", "total_elapsed"))) | .[] | tonumber ] | sort | (.[0]/.[1])*100 | .*100 | round/100')
    echo "::group::$repo stats"
    info "Pull: $pull%"
    info "Create: $create%"
    info "Run: $run%"
    echo "::endgroup::"
done <bench.json
