#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "$0")"
ai_dir="$(dirname "$script_path")"

# ./codexを実行したい場所のパスを渡す
codex_path="$1/codex"

ln -s "$ai_dir/codex" "$codex_path"

if ! docker network inspect mcp-share >/dev/null 2>&1; then
  docker network create \
    --driver bridge \
    --subnet 172.30.0.0/24 \
    --gateway 172.30.0.1 \
    mcp-share
fi

echo "codex created: $codex_path"
