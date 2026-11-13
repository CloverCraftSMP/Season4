#!/usr/bin/env bash
set -euo pipefail

source "$MISE_LIB/logger.sh"

CHANGELOG="${CHANGELOG:-$MISE_PROJECT_ROOT/CHANGELOG.md}"

# Prints the body of a `## [<name>]` section of CHANGELOG.md, without surrounding blank lines.
changelog_section() {
    awk -v name="$1" '
        /^## \[/ {
            if (found) exit
            found = index($0, "[" name "]") > 0
            next
        }
        found
    ' "$CHANGELOG" | sed -e '/[^[:space:]]/,$!d' | sed -e ':a' -e '/^[[:space:]]*$/{$d;N;ba' -e '}'
}

changelog_has_section() {
    grep -qF "## [$1]" "$CHANGELOG"
}

# Prints the notes players should see for a version: its own section, else [Unreleased] (a release
# is rendered before ci:finalize-changelog renames it), else the newest released section.
changelog_notes_for() {
    local notes latest
    notes="$(changelog_section "$1")"
    [[ -z "$notes" ]] && notes="$(changelog_section Unreleased)"
    if [[ -z "$notes" ]]; then
        latest="$(grep -m1 -oP '^## \[\K[0-9][^]]*' "$CHANGELOG" || true)"
        [[ -n "$latest" ]] && notes="$(changelog_section "$latest")"
    fi
    printf '%s\n' "$notes"
}
