#!/usr/bin/env bash
#MISE description="Generates a drag-and-drop Prism instance linked to this repository using Packwiz"
#MISE hide=true
set -euo pipefail

if [ ! -f pack.toml ]; then
    echo "pack.toml not found! Please run this in the root of your packwiz repository."
    exit 1
fi

echo "Reading versions from pack.toml..."
MC_VERSION=$(grep -E '^\s*minecraft\s*=' pack.toml | cut -d'"' -f2 || true)
FABRIC_VERSION=$(grep -E '^\s*fabric\s*=' pack.toml | cut -d'"' -f2 || true)

if [ -z "$MC_VERSION" ] || [ -z "$FABRIC_VERSION" ]; then
    echo "Error: Could not extract Minecraft or Fabric versions from pack.toml."
    echo "Make sure they are defined under the [versions] block!"
    exit 1
fi

echo "Detected Minecraft $MC_VERSION with Fabric $FABRIC_VERSION"

mkdir -p .mise/prism-instance/.minecraft

echo "Downloading packwiz-installer-bootstrap.jar..."
curl -sSL -o .mise/prism-instance/.minecraft/packwiz-installer-bootstrap.jar \
    https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar

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
PreLaunchCommand="\$INST_JAVA" -jar packwiz-installer-bootstrap.jar "${REPO_PATH}/pack.toml"
OverridePerformance=true
EnableMangoHud=true
EOF

echo "Packaging instance..."
(
    shopt -s dotglob
    cd .mise/prism-instance
    jar cMf "../Season 4 Dev.zip" *
)

echo "Success! Drag and drop '.mise/Season 4 Dev.zip' into Prism Launcher to import it."
echo "Every time you launch this instance, Prism will automatically sync your local packwiz changes!"