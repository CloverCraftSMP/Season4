#!/usr/bin/env bash
set -euo pipefail

source "$MISE_LIB/logger.sh"
source "$MISE_LIB/toml.helper.sh"

# Crash Assistant compares a player's mods/ against config/crash_assistant/modlist.json to report
# which mods they added, removed or updated, and whether a crashing mod is part of the pack.
# Normally a "modpack creator" launching the game writes that file; we generate it from packwiz
# metadata instead so it always matches the published pack.
#
# Entries mirror what Crash Assistant writes itself: jarName (the file name in mods/), modId,
# name and version from fabric.mod.json, and modrinthHash (the jar's SHA-1). Matching is by jar
# name, then hash, then mod id, so all four need to be right for a clean diff.
#
# Every client-side mod is listed, flavor-gated ones included, so a player on a lighter flavor
# shows those as "removed" while anything they added themselves stands out as "added".

MOD_CACHE_DIR="${PACKDEV_MOD_CACHE:-$MISE_PROJECT_ROOT/.mise/cache/mods}"

# Downloads a jar into the cache (keyed by its sha512) unless it is already there, and prints its path.
_cached_jar() {
    local url="$1" sha512="$2"
    local jar="$MOD_CACHE_DIR/$sha512.jar"

    if [[ ! -f "$jar" ]]; then
        local tmp="$jar.part"
        curl -sSfL --retry 3 -o "$tmp" "$url" || {
            rm -f "$tmp"
            log_fatal "downloading $url failed"
        }
        if [[ "$(sha512sum "$tmp" | cut -d' ' -f1)" != "$sha512" ]]; then
            rm -f "$tmp"
            log_fatal "$url does not match the sha512 in its .pw.toml"
        fi
        mv "$tmp" "$jar"
    fi
    printf '%s\n' "$jar"
}

# Prints one modlist.json entry for a .pw.toml, or nothing for server-only mods.
_modlist_entry() {
    local pw="$1"
    local side filename url sha512 name jar meta

    side="$(_get_toml_val "$pw" side)"
    [[ "$side" == "server" ]] && return 0

    filename="$(_get_toml_val "$pw" filename)"
    url="$(_get_toml_val "$pw" url)"
    sha512="$(_get_toml_val "$pw" hash)"
    name="$(_get_toml_val "$pw" name)"

    jar="$(_cached_jar "$url" "$sha512")"

    # Fabric tolerates raw newlines/tabs inside strings (multi-line descriptions) but jq doesn't,
    # so turn every control character into a space. If it still won't parse, list the jar without
    # an id/version rather than failing the build.
    if ! meta="$(unzip -p "$jar" fabric.mod.json 2>/dev/null | tr '\000-\037' ' ' |
        jq -ec '{modId: .id, name: (.name // .id), version: (.version | tostring)}' 2>/dev/null)"; then
        log_warn "could not read fabric.mod.json from $filename, listing it without a mod id"
        meta="$(jq -nc --arg name "$name" '{name: $name}')"
    fi

    jq -c \
        --arg jarName "$filename" \
        --arg sha1 "$(sha1sum "$jar" | cut -d' ' -f1)" \
        '{jarName: $jarName} + . + {modrinthHash: $sha1}' <<<"$meta"
}

# Writes <dir>/config/crash_assistant/modlist.json for the pack checked out in <dir>.
write_crash_assistant_modlist() {
    local dir="$1"
    local out="$dir/config/crash_assistant/modlist.json"
    local pw

    mkdir -p "$MOD_CACHE_DIR" "$(dirname "$out")"

    for pw in "$dir"/mods/*.pw.toml; do
        _modlist_entry "$pw"
    done | jq -s 'sort_by(.jarName | ascii_downcase)' >"$out"

    log_info "Wrote Crash Assistant modlist ($(jq length "$out") mods)"
}
