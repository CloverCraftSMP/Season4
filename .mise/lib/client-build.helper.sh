#!/usr/bin/env bash
set -euo pipefail

source "$MISE_LIB/logger.sh"

# Resolves PACKDEV_CHANNEL and PACKDEV_VERSION. Values set by the caller win;
# anything left empty is derived from git: an exact tag is prod, a tagged
# ancestor is staging, otherwise local.
resolve_release() {
    local channel="${PACKDEV_CHANNEL:-}"
    local version="${PACKDEV_VERSION:-}"
    local tag derived_channel derived_version

    if tag="$(git describe --tags --exact-match 2>/dev/null)"; then
        derived_channel="prod"
        derived_version="${tag#v}"
    elif tag="$(git describe --tags 2>/dev/null)"; then
        derived_channel="staging"
        derived_version="${tag#v}"
    else
        derived_channel="local"
        derived_version="dev-$(git rev-parse --short HEAD 2>/dev/null || echo 'local')"
    fi

    export PACKDEV_CHANNEL="${channel:-$derived_channel}"
    export PACKDEV_VERSION="${version:-$derived_version}"
}

# Prints the pack.toml URL unsup should bootstrap from for a channel.
pack_source_url() {
    case "$1" in
        prod | staging) echo "${PACKDEV_REPO_RAW}/$1/pack.toml" ;;
        local) echo "http://localhost:8080/pack.toml" ;;
        *) log_fatal "unknown channel '$1' (expected local, staging or prod)" ;;
    esac
}

# Renders a pack checkout in place: injects the version, points unsup.ini at
# the channel's source and refreshes the packwiz hashes the edits invalidated.
render_pack() {
    local dir="$1" version="$2" source_url="$3"

    find "$dir/pack.toml" "$dir/config" -type f -exec sed -i "s|@modpack_version@|${version}|g" {} +
    log_debug "Injected version $version"

    if grep -q '^source=' "$dir/unsup.ini"; then
        sed -i "s|^source=.*|source=${source_url}|" "$dir/unsup.ini"
    else
        printf 'source=%s\n' "$source_url" >>"$dir/unsup.ini"
    fi
    log_debug "Pointed unsup at $source_url"

    # TODO: update crash assistant config forcefully?

    (cd "$dir" && packwiz refresh)
}

# Copies the pack into a temp dir, renders it for the resolved channel and
# cds into it. Pair with `trap cleanup EXIT`.
build() {
    resolve_release
    mkdir -p "$PACKDEV_BUILD_ROOT"

    local source_url
    source_url="$(pack_source_url "$PACKDEV_CHANNEL")"
    log_info "Building $PACKDEV_VERSION (channel: $PACKDEV_CHANNEL, source: $source_url)"

    BUILD_DIR="$(mktemp -d)"
    export BUILD_DIR

    tar -C "$MISE_PROJECT_ROOT" \
        --exclude=./.git --exclude=./build --exclude=./run --exclude=./.ci \
        -cf - . | tar -C "$BUILD_DIR" -xf -
    log_debug "Copied source to $BUILD_DIR"

    render_pack "$BUILD_DIR" "$PACKDEV_VERSION" "$source_url"
    cd "$BUILD_DIR"
}

fetch_unsup() {
    local target_path="$1"
    mkdir -p "$(dirname "$target_path")"
    log_info "Downloading unsup (v${UNSUP_VERSION})..."
    curl -sSfL -o "$target_path" "https://git.sleeping.town/exa/unsup/releases/download/v${UNSUP_VERSION}/unsup-${UNSUP_VERSION}.jar"
}

cleanup() {
    if [[ -n "${BUILD_DIR:-}" && -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
        log_debug "Cleaned up $BUILD_DIR"
    fi
}
