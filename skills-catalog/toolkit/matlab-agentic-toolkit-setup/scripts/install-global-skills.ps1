# Copyright 2026 The MathWorks, Inc.
param(
    [string]$ToolkitRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) {
    $ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
} else {
    $ToolkitRoot = (Resolve-Path $ToolkitRoot).Path
}

# Determine skills directory: prefer ~/.agents/skills/, fall back to
# ~/.copilot/skills/ if the primary cannot be created.
$skillsRoot = Join-Path $HOME ".agents\skills"
try {
    New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null
} catch {
    $skillsRoot = Join-Path $HOME ".copilot\skills"
    New-Item -ItemType Directory -Force -Path $skillsRoot | Out-Null
}

# Auto-discover all published skills (directories containing manifest.yaml).
$skillDirs = Get-ChildItem -Recurse -Filter "manifest.yaml" -Path (Join-Path $ToolkitRoot "skills-catalog") |
    Where-Object { ($_.FullName -replace '\\','/') -match 'skills-catalog/[^/]+/[^/]+/manifest\.yaml$' } |
    ForEach-Object { $_.Directory } |
    Sort-Object FullName

foreach ($skillDir in $skillDirs) {
    $linkPath = Join-Path $skillsRoot $skillDir.Name
    if (Test-Path $linkPath) {
        Remove-Item -Force -Recurse $linkPath
    }

    try {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $skillDir.FullName | Out-Null
    } catch {
        New-Item -ItemType Junction -Path $linkPath -Target $skillDir.FullName | Out-Null
    }

    Write-Output ("Linked {0} -> {1}" -f $linkPath, $skillDir.FullName)
}

Write-Output ""
Write-Output "Skills directory: $skillsRoot"
