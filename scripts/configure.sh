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

# shellcheck source=./scripts/_utils.sh
source _utils.sh

# NOTE: this env var is used by kind tool
export KIND_CLUSTER_NAME=k8s

function _create_cluster {
    if ! sudo "$(command -v kind)" get clusters | grep -e "$KIND_CLUSTER_NAME"; then
        sudo -E kind create cluster --config cluster-config.yml
        mkdir -p "$HOME/.kube"
        sudo chown -R "$USER": "$HOME/.kube"
        sudo -E kind get kubeconfig | tee "$HOME/.kube/config"

        registry_dir="/etc/containerd/certs.d/localhost:5000"
        registry_name="$(sudo docker ps --filter ancestor=registry:2 --format "{{.Names}}")"
        for node in $(sudo -E kind get nodes); do
            sudo docker exec "${node}" mkdir -p "${registry_dir}"
            cat <<EOF | sudo docker exec -i "${node}" cp /dev/stdin "${registry_dir}/hosts.toml"
[host."http://${registry_name}:5000"]
EOF
        done

        if [ "$(sudo docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${registry_name}")" = 'null' ]; then
            sudo docker network connect kind "${registry_name}"
        fi

        # editorconfig-checker-disable
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
        # editorconfig-checker-enable
    fi
}

function _build_img {
    local name="localhost:5000/java-server:$1"
    local dockerfile=${2-Dockerfile}
    local squash=${3-false}

    before=$(curl -s http://localhost:5000/status/format/json | jq '.upstreamZones["::nogroups"][0].inBytes')
    [[ $before == "null" ]] && before=0
    if [[ -z $(sudo docker images "$name" -q) ]]; then
        sudo docker build --tag "$name" --file "$dockerfile" .
        [[ $squash != "false" ]] && sudo docker-squash "$name"
        sudo docker push "$name"
    fi
    after=$(curl -s http://localhost:5000/status/format/json | jq '.upstreamZones["::nogroups"][0].inBytes')
    data_transf=$((after - before))
    info "Registry - Data Transfer: $(printf "%sB\nMB" "$data_transf" | units --quiet --one-line --compact)MB"

    info "$name - Image security issues"
    trivy image "$name" --quiet || :
}

function _build_imgs {
    pushd .. >/dev/null

    _build_img v1
    _build_img v2 Dockerfile.distroless "true"
    curl -s http://localhost:5000/v2/java-server/tags/list | jq -r .

    popd >/dev/null
}

function main {
    sudo mkdir -p /var/local/images
    sudo docker compose up -d

    _create_cluster
    _build_imgs
}

if [[ ${__name__:-"__main__"} == "__main__" ]]; then
    main
fi
