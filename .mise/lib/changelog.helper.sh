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
