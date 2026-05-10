#!/usr/bin/env bash

set -euo pipefail

docker network create \
  --driver bridge \
  --subnet 172.30.0.0/24 \
  --gateway 172.30.0.1 \
  mcp-share
