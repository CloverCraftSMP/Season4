#!/usr/bin/env bash
set -euo pipefail

source "$MISE_LIB/logger.sh"

preflight() {
    local channel="${PACKDEV_CHANNEL:-dev}"
    local version="${PACKDEV_VERSION:-}"

    if [[ -z "$version" ]]; then
        if git describe --tags --exact-match >/dev/null 2>&1; then
            version="$(git describe --tags --exact-match)"
            channel="prod"
        elif git describe --tags >/dev/null 2>&1; then
            version="$(git describe --tags)"
            channel="staging"
        else
            version="dev-$(git rev-parse --short HEAD 2>/dev/null || echo 'local')"
            channel="local"
        fi
    fi

    PACKDEV_CHANNEL="$channel"
    PACKDEV_VERSION="$version"

    mkdir -p "$PACKDEV_BUILD_ROOT"

    log_info "=== PREFLIGHT ===\nChannel: $PACKDEV_CHANNEL\nVersion: $PACKDEV_VERSION"
}

_replace_vars_in_configs() {
    local target="$1"
    local replacement="$2"
    shift 2

    if [ $# -eq 0 ]; then
        return 0
    fi

    find "$@" -type f -exec sed -i.bak "s|$target|$replacement|g" {} +
}

build() {
    preflight

    log_info "Building Client for $PACKDEV_VERSION (Channel: $PACKDEV_CHANNEL)"

    local repo_base_raw="${PACKDEV_REPO_RAW:-}"
    local bootstrap_url=""

    case "$PACKDEV_CHANNEL" in
        prod) bootstrap_url="${repo_base_raw}/prod/pack.toml" ;;
        staging) bootstrap_url="${repo_base_raw}/staging/pack.toml" ;;
        local) bootstrap_url="http://localhost:8080/pack.toml" ;;
        *)
            echo "Error: unknown channel '$PACKDEV_CHANNEL' (expected prod, staging, or local)." >&2
            exit 1
            ;;
    esac

    log_debug "Creating temp directory"
    local build_dir="$(mktemp -d)"
    log_debug "Created temp dir and put script into exit trap for cleanup on temp dir"

    log_info "Temp dir created at $build_dir [repo url: $repo_base_raw, bootstrap: $bootstrap_url]"

    cp -r ./. "$build_dir"/
    log_debug "Copied source to temp"

    _replace_vars_in_configs "@modpack_version@" "$PACKDEV_VERSION" "$build_dir/pack.toml" "$build_dir/config"

    log_debug "Replaced modpack version"

    if [ -f "$build_dir/unsup.ini" ]; then
        _replace_vars_in_configs "source=.*" "source=${bootstrap_url}" "$build_dir/unsup.ini"
    fi

    log_debug "Replaced unsup source"

    packwiz refresh

    log_info "Build success for channel [$PACKDEV_CHANNEL]"

    cd "$build_dir"
    export BUILD_DIR="$build_dir"
}

fetch_unsup() {
    local target_path="$1"
    local target_dir="$(dirname "$target_path")"
    mkdir -p "$target_dir"
    log_debug "Made $target_dir for downloading unsup into" 
    log_info "Downloading unsup (v${UNSUP_VERSION})..."
    log_debug "Downloading to $target_path"
    curl -sSL -o "$target_path" "https://git.sleeping.town/exa/unsup/releases/download/v${UNSUP_VERSION}/unsup-${UNSUP_VERSION}.jar"
}

cleanup() {
    if [ -z "${build_dir:-}" ] || [ ! -d "$build_dir" ]; then
        return 0
    fi

    rm -rf "$build_dir"
    log_debug "Clean up temp build dir $build_dir"
}