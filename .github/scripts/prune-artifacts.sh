#!/usr/bin/env bash
set -euo pipefail

echo "Looking for old Server-Package artifacts..."

OLD_ARTIFACTS=$(gh api repos/$GITHUB_REPOSITORY/actions/artifacts --paginate \
-q '.artifacts | map(select(.name == "Server-Package")) | sort_by(.created_at) | reverse | .[5:] | .[].id')

if [ -z "$OLD_ARTIFACTS" ]; then
echo "Less than 5 artifacts found."
exit 0
fi

for ID in $OLD_ARTIFACTS; do
echo "Deleting old artifact ID: $ID"
gh api -X DELETE repos/$GITHUB_REPOSITORY/actions/artifacts/$ID
done

echo "Cleanup complete!"