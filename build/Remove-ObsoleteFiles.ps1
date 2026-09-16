#Requires -Version 7.4
<#
.SYNOPSIS
    Removes V1 files from this distribution repository that V2 replaced. Safe to run repeatedly.
.EXAMPLE
    ./build/Remove-ObsoleteFiles.ps1 -WhatIf
    ./build/Remove-ObsoleteFiles.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()
$root = Split-Path -Parent $PSScriptRoot
$obsolete = (Get-Content (Join-Path $PSScriptRoot 'obsolete-files.json') -Raw | ConvertFrom-Json).paths
$removed = 0
foreach ($rel in $obsolete) {
    $path = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $path)) { continue }
    if ($PSCmdlet.ShouldProcess($rel, 'Remove obsolete V1 file')) {
        Remove-Item -LiteralPath $path -Recurse -Force
        $removed++
        Write-Host "removed $rel"
    }
}
Write-Host "Obsolete V1 entries removed: $removed"

