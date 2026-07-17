#!/usr/bin/env bash
#MISE description="Generates a drag-and-drop Prism instance linked to this repository"
#MISE hide=true
set -euo pipefail

if [ ! -f pakku-lock.json ]; then
    echo "pakku-lock.json not found!"
    exit 1
fi

echo "Reading versions from pakku-lock.json..."
MC_VERSION=$(jq -r '.mc_versions[0]' pakku-lock.json)
FABRIC_VERSION=$(jq -r '.loaders.fabric' pakku-lock.json)
echo "Detected Minecraft $MC_VERSION with Fabric $FABRIC_VERSION"

mkdir -p .mise/prism-instance

cat << EOF > .mise/prism-instance/mmc-pack.json
{
    "components": [
        { "important": true, "uid": "net.minecraft", "version": "${MC_VERSION}" },
        { "uid": "net.fabricmc.fabric-loader", "version": "${FABRIC_VERSION}" }
    ],
    "formatVersion": 1
}
EOF

REPO_PATH=$(pwd)
cat << EOF > .mise/prism-instance/instance.cfg
[General]
InstanceType=OneSix
OverrideCommands=true
PreLaunchCommand=\\$INST_JAVA "-Ddev.repo.path=${REPO_PATH}" "${REPO_PATH}/DevLaunch.java"
OverridePerformance=true
EnableMangoHud=true
EOF

cd .mise/prism-instance
jar cMf "../Season 4 Dev.zip" *
cd ../..

echo "Success! Drag and drop '.mise/Season 4 Dev.zip' into Prism Launcher to import it."