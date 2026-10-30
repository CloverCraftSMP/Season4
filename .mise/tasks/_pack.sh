#!/usr/bin/env bash
#MISE hide=true
set -euo pipefail

load_fabric_server_toml() {
    if [ ! -f fabric-server.pw.toml ]; then
        echo "Error: fabric-server.pw.toml not found!" >&2
        exit 1
    fi

    TMP_FS_URL=$(grep -E '^\s*url\s*=' fabric-server.pw.toml | cut -d'"' -f2 || true)
    TMP_FS_HASH=$(grep -E '^\s*hash\s*=' fabric-server.pw.toml | cut -d'"' -f2 || true)

    if [ -z "$TMP_FS_URL" ] || [ -z "$TMP_FS_HASH" ]; then
        echo "Error: Could not parse URL or has from fabric-server.pw.toml." >&2
        exit 1
    fi

    export TMP_FS_URL TMP_FS_HASH
}