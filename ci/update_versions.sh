#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o errexit
set -o pipefail
if [[ ${DEBUG:-false} == "true" ]]; then
    set -o xtrace
fi

last_version=$(curl -sL https://registry.hub.docker.com/v2/repositories/kindest/node/tags | python -c 'import json,sys,re;versions=[obj["name"][1:] for obj in json.load(sys.stdin)["results"] if re.match("^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$",obj["name"])];print("\n".join(versions))' | uniq | sort -rn | head -n 1)

# editorconfig-checker-disable
cat <<EOT >scripts/cluster-config.yml
---
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024-$(date +"%Y")
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
kubeadmConfigPatches:
- |
  apiVersion: kubelet.config.k8s.io/v1beta1
  kind: KubeletConfiguration
  serializeImagePulls: false
nodes:
  - role: control-plane
    image: kindest/node:v$last_version
  - role: worker
    image: kindest/node:v$last_version
  - role: worker
    image: kindest/node:v$last_version
  - role: worker
    image: kindest/node:v$last_version
  - role: worker
    image: kindest/node:v$last_version
  - role: worker
    image: kindest/node:v$last_version
  - role: worker
    image: kindest/node:v$last_version
EOT
# editorconfig-checker-enable

# Update GitHub Action commit hashes
gh_actions=$(grep -r "uses: [a-zA-Z\-]*/[\_a-z\-]*@" .github/ | sed 's/@.*//' | awk -F ': ' '{ print $3 }' | sort -u)
for action in $gh_actions; do
    commit_hash=$(git ls-remote "https://github.com/$action" | grep 'refs/tags/[v]\?[0-9][0-9\.]*$' | sed 's|refs/tags/[vV]\?[\.]\?||g' | sort -u -k2 -V | tail -1 | awk '{ printf "%s # %s\n",$1,$2 }')
    # shellcheck disable=SC2267
    grep -ElRZ "uses: $action@" .github/ | xargs -0 -l sed -i -e "s|uses: $action@.*|uses: $action@$commit_hash|g"
done
make fmt
