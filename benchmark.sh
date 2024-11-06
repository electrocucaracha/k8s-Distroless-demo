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

# Install requeriments
if ! command -v docker >/dev/null; then
    export PKG="docker"
fi
# NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
curl -fsSL http://bit.ly/install_pkg | PKG_COMMANDS_LIST="jq" bash

if ! command -v nerdctl >/dev/null; then
    curl -s "https://i.jpillora.com/containerd/nerdctl!" | bash
fi

[ ! -d /opt/hello-bench ] && sudo git clone https://github.com/nydusaccelerator/hello-bench/ /opt/hello-bench

for image in python:3 alpine:3 ubuntu:20.04 ubuntu:22.04; do
    sudo /opt/hello-bench/hello.py --engine docker --op run --images "$image" >/dev/null
    info "$image pull elapsed: $(jq '[ with_entries(select(.key | startswith("pull_elapsed", "total_elapsed"))) | .[] | tonumber ] | sort | (.[0]/.[1])*100' bench.json)%"
done
