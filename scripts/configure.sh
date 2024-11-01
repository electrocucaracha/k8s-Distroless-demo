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

get_status=""
registry_ip=""

# shellcheck disable=SC2064
trap "$get_status" ERR

function _create_cluster {
    if ! sudo "$(command -v kind)" get clusters | grep -e "$KIND_CLUSTER_NAME"; then
        # NOTE: Docker IPv6 is disable in codespaces which results in a failure (https://github.com/kubernetes-sigs/kind/issues/3748#issuecomment-2394487000)
        if [[ ${CODESPACES-false} == "true" ]]; then
            sudo docker network create -d=bridge \
                -o com.docker.network.bridge.enable_ip_masquerade=true \
                -o com.docker.network.driver.mtu=1500 \
                --subnet fc00:f853:ccd:e793::/64 kind || :
            sudo -E kind create cluster
        else
            sudo -E kind create cluster --config cluster-config.yml
        fi
        mkdir -p "$HOME/.kube"
        sudo chown -R "$USER": "$HOME/.kube"
        sudo -E kind get kubeconfig | tee "$HOME/.kube/config"

        # NOTE: Connecting to the KinD network here guarantees the order of the IP addresess
        registry_name="$(sudo docker ps --filter ancestor=electrocucaracha/nginx:vts --format "{{.Names}}")"
        if [ "$(sudo docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${registry_name}")" = 'null' ]; then
            sudo docker network connect kind "${registry_name}"
        fi

        registry_ip="$(sudo docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' "$registry_name" | awk 'NR==1{print $1}')"
        registry_dir="/etc/containerd/certs.d/$registry_ip:5001"
        for node in $(sudo -E docker ps --filter name=k8s --quiet); do
            sudo docker exec "${node}" mkdir -p "${registry_dir}"
            cat <<EOF | sudo docker exec -i "${node}" cp /dev/stdin "${registry_dir}/hosts.toml"
[host."http://${registry_ip}:5001"]
EOF
        done

        # editorconfig-checker-disable
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "$registry_ip:5001"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
        # editorconfig-checker-enable
    fi
}

function _build_img {
    local name="${registry_ip}:5001/java-server:$1"
    local dockerfile=${2-Dockerfile}
    local squash=${3-false}

    curl -s "http://${registry_ip}:5001/v2/_catalog" | jq -r .
    before=$(curl -s "http://${registry_ip}:5001/status/format/json" | jq '.upstreamZones["::nogroups"][0].inBytes' || :)
    [[ ${before-null} == "null" ]] && before=0
    if [[ -z $(sudo docker images "$name" -q) ]]; then
        if [[ $squash != "false" ]]; then
            sudo docker build --tag "$name" --file "$dockerfile" .
            sudo docker-squash "$name"
            sudo docker push "$name"
        else
            sudo docker build --tag "$name" --file "$dockerfile" --push .
        fi
    fi
    after=$(curl -s "http://${registry_ip}:5001/status/format/json" | jq '.upstreamZones["::nogroups"][0].inBytes')
    data_transf=$((after - before))
    info "Registry - Data Transfer: $(printf "%sB\nMB" "$data_transf" | units --quiet --one-line --compact)MB"

    info "$name - Image security issues"
    newgrp docker <<BASH
    trivy image "$name" --quiet || :
BASH
}

function _build_imgs {
    pushd .. >/dev/null

    _build_img v1
    _build_img v2 Dockerfile.distroless "true"
    curl -s "http://${registry_ip}:5001/v2/java-server/tags/list" | jq -r .
    sudo docker system prune -f

    popd >/dev/null
}

function main {
    sudo mkdir -p /var/local/images
    get_status="sudo docker compose ps;"
    sudo docker compose up -d

    get_status="kubectl get nodes; kubectl get pods -A;"
    _create_cluster
    get_status="sudo docker images;"
    _build_imgs
}

if [[ ${__name__:-"__main__"} == "__main__" ]]; then
    main
fi
