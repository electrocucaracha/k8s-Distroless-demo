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
    export PKG_DEBUG=true
fi

export PKG_KREW_PLUGINS_LIST=" "
export PKG_DOCKER_INSTALL_DIVE="true"
export PKG_DOCKER_INSTALL_REGCTL="true"

# Install dependencies
# NOTE: Shorten link -> https://github.com/electrocucaracha/pkg-mgr_scripts
curl -fsSL http://bit.ly/install_pkg | PKG_COMMANDS_LIST="kind,kubectl,jq,units" PKG="docker pip helm" PKG_UPDATE="true" bash
sudo pip install docker-squash

if ! command -v trivy >/dev/null; then
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install trivy -y
    newgrp docker <<BASH
    trivy image --download-java-db-only --quiet || :
BASH
fi

sudo docker buildx create --use --name lazy-builder --buildkitd-flags '--oci-worker-snapshotter=stargz'
sudo docker buildx inspect --bootstrap lazy-builder

! grep -q 172.19.0.3 /etc/docker/daemon.json && jq '.["insecure-registries"] += ["172.19.0.3:5001"]' /etc/docker/daemon.json >/tmp/daemon.json && sudo mv /tmp/daemon.json /etc/docker/daemon.json
if [[ ${CODESPACES-false} == "true" ]]; then
    sudo pkill dockerd && sudo pkill containerd
    /usr/local/share/docker-init.sh
fi
