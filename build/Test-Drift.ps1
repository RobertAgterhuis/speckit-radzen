#Requires -Version 7.4
<#
.SYNOPSIS
    Fails when generated files (integrations/, core/antipatterns/*.md) differ from what the generators produce.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('skr-drift-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$problems = [System.Collections.Generic.List[string]]::new()

function Compare-Tree([string] $expected, [string] $actual, [string] $label, [string] $filter = '*') {
    $e = @{}; $a = @{}
    foreach ($f in Get-ChildItem -Path $expected -Recurse -File -Force -Filter $filter) { $e[[System.IO.Path]::GetRelativePath($expected, $f.FullName) -replace '\\', '/'] = $f.FullName }
    if (Test-Path $actual) { foreach ($f in Get-ChildItem -Path $actual -Recurse -File -Force -Filter $filter) { $a[[System.IO.Path]::GetRelativePath($actual, $f.FullName) -replace '\\', '/'] = $f.FullName } }
    foreach ($k in $e.Keys) {
        if (-not $a.ContainsKey($k)) { $problems.Add("$label/$k is missing (run the generator)"); continue }
        $x = (Get-Content $e[$k] -Raw) -replace "`r`n", "`n"
        $y = (Get-Content $a[$k] -Raw) -replace "`r`n", "`n"
        if ($x -ne $y) { $problems.Add("$label/$k differs from generated output") }
    }
    foreach ($k in $a.Keys) { if (-not $e.ContainsKey($k)) { $problems.Add("$label/$k is not produced by the generator (stale file)") } }
}

try {
    & (Join-Path $PSScriptRoot 'Build-Adapters.ps1') -OutputRoot (Join-Path $tmp 'integrations') | Out-Null
    Compare-Tree (Join-Path $tmp 'integrations') (Join-Path $root 'integrations') 'integrations'
    & (Join-Path $PSScriptRoot 'Build-Catalog.ps1') -OutputRoot (Join-Path $tmp 'catalog') | Out-Null
    Compare-Tree (Join-Path $tmp 'catalog') (Join-Path $root 'core' 'antipatterns') 'core/antipatterns' '*.md'
}
finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }

if ($problems.Count) {
    $problems | ForEach-Object { Write-Host "DRIFT: $_" -ForegroundColor Red }
    throw "$($problems.Count) generated file(s) out of date. Run build/Build-Adapters.ps1 and build/Build-Catalog.ps1."
}
Write-Host 'No drift: generated files are up to date.' -ForegroundColor Green
