#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2025
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

function _build_img {
    local name="java-server:$1"
    local dockerfile=${2-Dockerfile}

    if [[ -z $(sudo docker images "$name" -q) ]]; then
        sudo docker buildx build --tag "$name" --file "$dockerfile" .
    fi
}

function _build_imgs {
    _build_img v1
    _build_img v2 Dockerfile.distroless
    _build_img v3 Dockerfile.graalvm
    sudo docker system prune -f
}

echo "::group::Install requeriments"
if ! command -v docker >/dev/null; then
    # NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
    curl -fsSL http://bit.ly/install_pkg | PKG="docker" bash
fi

echo "::group::Build docker images"
_build_imgs
