#!/usr/bin/env bash
#MISE description="Downloads or updates the latest pakku.jar"
mkdir -p .mise
curl -sLo .mise/pakku.jar "https://github.com/juraj-hrivnak/Pakku/releases/latest/download/pakku.jar"
echo "Pakku updated successfully!"