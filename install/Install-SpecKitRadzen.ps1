[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Repository = (Get-Location).Path,

    [ValidateSet("Auto","Claude","Codex","Copilot","Generic","All")]
    [string]$Agent = "Auto",

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path $Repository).Path
$dist = Split-Path -Parent $PSScriptRoot
$coreSource = Join-Path $dist "core"
$coreTarget = Join-Path $repo ".speckit\radzen\core"

function Copy-Safe([string]$Source, [string]$Destination) {
    if ((Test-Path $Destination) -and -not $Force) {
        throw "Destination already exists: $Destination. Use -Force to replace managed Spec Kit files."
    }
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item $Source $Destination -Recurse -Force
}

Write-Host "Installing Spec Kit Radzen into: $repo"
Copy-Safe $coreSource $coreTarget

$detected = @()
if ($Agent -eq "Auto") {
    if (Test-Path (Join-Path $repo ".claude")) { $detected += "Claude" }
    if (Test-Path (Join-Path $repo ".agents")) { $detected += "Codex" }
    if (Test-Path (Join-Path $repo ".github")) { $detected += "Copilot" }
    if ($detected.Count -eq 0) { $detected += "Generic" }
} elseif ($Agent -eq "All") {
    $detected = @("Claude","Codex","Copilot")
} else {
    $detected = @($Agent)
}

foreach ($a in $detected) {
    $source = Join-Path $dist ("integrations\" + $a.ToLower())
    if (-not (Test-Path $source)) { throw "Integration source missing: $source" }

    Get-ChildItem $source -Force | ForEach-Object {
        $dest = Join-Path $repo $_.Name
        if ($_.PSIsContainer) {
            # Merge adapter directories without deleting unrelated repository configuration.
            Get-ChildItem $_.FullName -Recurse -File -Force | ForEach-Object {
                $relative = $_.FullName.Substring($source.Length).TrimStart('\','/')
                $targetFile = Join-Path $repo $relative
                if ((Test-Path $targetFile) -and -not $Force) {
                    throw "Managed integration file exists: $targetFile. Use -Force to overwrite it."
                }
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetFile) | Out-Null
                Copy-Item $_.FullName $targetFile -Force
            }
        } else {
            if ((Test-Path $dest) -and -not $Force) {
                Write-Warning "Skipping existing root file: $dest"
            } else {
                Copy-Item $_.FullName $dest -Force
            }
        }
    }
    Write-Host "Installed adapter: $a"
}

Write-Host ""
Write-Host "Spec Kit Radzen installed."
Write-Host "Canonical core: .speckit\radzen\core"
Write-Host "Agents: $($detected -join ', ')"
Write-Host "Configure Radzen MCP separately in your AI client; never commit credentials."
