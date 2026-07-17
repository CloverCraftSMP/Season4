#!/usr/bin/env pwsh
#MISE description="Downloads or updates the latest pakku.jar"
#MISE hide=true
if (-not (Test-Path ".mise")) {
    New-Item -ItemType Directory -Force -Path ".mise" | Out-Null
}

Invoke-WebRequest -Uri "https://github.com/juraj-hrivnak/Pakku/releases/latest/download/pakku.jar" -OutFile ".mise/pakku.jar"

Write-Host "Pakku updated successfully!"