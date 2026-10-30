#!/usr/bin/env bash
#MISE hide=true
set -euo pipefail

SERVER_BASE_DIR="$MISE_PROJECT_ROOT/.ci/server"

REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
REPO_SLUG=$(printf '%s' "$REMOTE_URL" \
    | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')

if [ -z "$REPO_SLUG" ] || [ "$REPO_SLUG" = "$REMOTE_URL" ]; then
    REPO_SLUG="CloverCraftSMP/Season4"
fi

REPO_BASE_RAW="https://raw.githubusercontent.com/$REPO_SLUG"