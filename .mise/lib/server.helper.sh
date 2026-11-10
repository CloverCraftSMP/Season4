#!/usr/bin/env bash
set -euo pipefail

source "$MISE_LIB/logger.sh"

PACKWIZ_LOCAL_URL="http://localhost:8080/pack.toml"

packwiz_is_serving() {
    curl -sf --head "$PACKWIZ_LOCAL_URL" >/dev/null
}

require_packwiz_serving() {
    packwiz_is_serving || log_fatal "The local packwiz server is not running. Start it in another terminal with: mise run packwiz:serve"
}

minecraft_port_open() {
    (: </dev/tcp/127.0.0.1/25565) 2>/dev/null
}

require_port_free() {
    if minecraft_port_open; then
        log_fatal "Port 25565 is already in use"
    fi
}
