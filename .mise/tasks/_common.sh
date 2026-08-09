#!/usr/bin/env bash
#MISE hide=true
set -euo pipefail

SERVER_BASE_DIR="$MISE_PROJECT_ROOT/.ci/server"
REPO_BASE_RAW="https://raw.githubusercontent.com/CloverCraftSMP/Season4"

load_pack_versions() {
    if [ ! -f pack.toml ]; then
        echo "Error: pack.toml not found! Run this from the repository root." >&2
        exit 1
    fi

    MC_VERSION=$(grep -E '^\s*minecraft\s*=' pack.toml | cut -d'"' -f2 || true)
    FABRIC_VERSION=$(grep -E '^\s*fabric\s*=' pack.toml | cut -d'"' -f2 || true)

    if [ -z "$MC_VERSION" ] || [ -z "$FABRIC_VERSION" ]; then
        echo "Error: Could not parse Minecraft or Fabric versions from pack.toml." >&2
        exit 1
    fi

    export MC_VERSION FABRIC_VERSION
}

fetch_unsup() {
    local target_path="$1"
    mkdir -p "$(dirname "$target_path")"
    echo "Downloading latest unsup.jar..."
    curl -sSL -o "$target_path" "https://git.sleeping.town/exa/unsup/releases/download/v1.2.7/unsup-1.2.7.jar"
}

package_dir() {
    local src_dir="$1"
    local output_path="$2"
    echo "Creating package: $output_path"
    (
        shopt -s dotglob
        cd "$src_dir"
        zip -r "$output_path" . >/dev/null 2>&1 || jar cMf "$output_path" *
    )
}

ensure_server_running() {
    if ! curl -s --head http://localhost:8080/pack.toml > /dev/null; then
        echo "Error: The local packwiz server is not running!"
        echo "Please open a new terminal window and run: mise run serve"
        exit 1
    fi
}