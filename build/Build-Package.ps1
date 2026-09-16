#Requires -Version 7.4
<#
.SYNOPSIS
    Builds dist/speckit-radzen-<version>.zip (+ .sha256 and RELEASE_NOTES.md) from the repository.
#>
[CmdletBinding()]
param([string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$out = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $root 'dist' }
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$name = "speckit-radzen-$version"
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("skr-pkg-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$pkg = Join-Path $staging $name
$null = New-Item -ItemType Directory -Force -Path $pkg, $out

$include = @('core', 'tools', 'integrations', 'mcp', 'install', 'docs', 'README.md', 'CHANGELOG.md', 'LICENSE', 'VERSION', 'manifest.json')
foreach ($item in $include) {
    $src = Join-Path $root $item
    if (-not (Test-Path $src)) { throw "Missing $item" }
    Copy-Item -Path $src -Destination $pkg -Recurse -Force
}
# drop any build output accidentally present
Get-ChildItem $pkg -Recurse -Directory -Force | Where-Object Name -in 'bin', 'obj' | Remove-Item -Recurse -Force

$zip = Join-Path $out "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $pkg -DestinationPath $zip -CompressionLevel Optimal
$hash = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToLowerInvariant()
Set-Content -Path "$zip.sha256" -Value "$hash  $name.zip" -NoNewline

$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
$section = [regex]::Match($changelog, "(?ms)^## $([regex]::Escape($version)).*?(?=^## |\z)").Value.Trim()
Set-Content -Path (Join-Path $out 'RELEASE_NOTES.md') -Value @"
# Spec Kit Radzen $version

$section

## Install

``````powershell
Expand-Archive $name.zip -DestinationPath .
./$name/install/Install-SpecKitRadzen.ps1 -Repository <your repo>
``````

SHA-256: ``$hash``
"@
Remove-Item $staging -Recurse -Force
Write-Host "Package: $zip ($([math]::Round((Get-Item $zip).Length / 1KB)) KB)"
Write-Host "SHA-256: $hash"
