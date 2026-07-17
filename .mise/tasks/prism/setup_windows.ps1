#!/usr/bin/env pwsh
#MISE description="Generates a drag-and-drop Prism instance linked to this repository"
#MISE hide=true
if (-not (Test-Path "pakku-lock.json")) {
    Write-Host "pakku-lock.json not found!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path ".mise/prism-instance")) {
    New-Item -ItemType Directory -Force -Path ".mise/prism-instance" | Out-Null
}

Write-Host "Reading versions from pakku-lock.json and generating Prism pack..."

$jqFilter = '{ components: [ { important: true, uid: "net.minecraft", version: .mc_versions[0] }, { uid: "net.fabricmc.fabric-loader", version: .loaders.fabric } ], formatVersion: 1 }'
jq $jqFilter pakku-lock.json | Set-Content ".mise/prism-instance/mmc-pack.json"

$repoPath = (Get-Location).Path.Replace('\', '/')

$cfgContent = @"
[General]
InstanceType=OneSix
OverrideCommands=true
PreLaunchCommand=`$INST_JAVA "-Ddev.repo.path=$repoPath" "$repoPath/DevLaunch.java"
"@

Set-Content -Path ".mise/prism-instance/instance.cfg" -Value $cfgContent

Write-Host "Zipping instance..."
Compress-Archive -Path ".mise/prism-instance/*" -DestinationPath ".mise/Season 4 Dev.zip" -Force

Write-Host "Success! Drag and drop '.mise/Season 4 Dev.zip' into Prism Launcher to import it." -ForegroundColor Green