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

docker run --rm --name server -d "java-server:$1" >/dev/null
trap "docker kill server >/dev/null; sleep 1" EXIT
until [ "$(docker logs server)" == "Starting server at 8080 port" ]; do
    date +"%S,%3N"
done
