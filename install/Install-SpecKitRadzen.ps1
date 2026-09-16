#Requires -Version 7.4
<#
.SYNOPSIS
    Installs Spec Kit Radzen into a repository (bootstrap wrapper around the SpecKitRadzen module).
.EXAMPLE
    ./install/Install-SpecKitRadzen.ps1 -Repository G:\Repos\MyApp
.EXAMPLE
    ./install/Install-SpecKitRadzen.ps1 -Repository . -Agents claude,copilot -McpClient ClaudeCode,VSCode -Yes
.EXAMPLE
    ./install/Install-SpecKitRadzen.ps1 -Repository . -Update       # upgrade an existing (or V1) install
.EXAMPLE
    ./install/Install-SpecKitRadzen.ps1 -Repository . -Uninstall
.NOTES
    V1 parameter -Agent (Auto|Claude|Codex|Copilot|Generic|All) is still accepted.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)][string] $Repository = (Get-Location).Path,
    [ValidateSet('claude', 'copilot', 'codex', 'cursor', 'generic', 'all', 'auto')][string[]] $Agents = @(),
    [ValidateSet('Auto', 'Claude', 'Codex', 'Copilot', 'Cursor', 'Generic', 'All')][string] $Agent,
    [ValidateSet('ClaudeCode', 'VSCode', 'VisualStudio', 'Cursor', 'Codex')][string[]] $McpClient = @(),
    [switch] $Force,
    [switch] $Yes,
    [switch] $EnableHooks,
    [switch] $Update,
    [switch] $Uninstall,
    [switch] $Verify
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'Spec Kit Radzen requires PowerShell 7.4 or later (pwsh).' }
$dist = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $dist 'tools' 'SpecKitRadzen' 'SpecKitRadzen.psd1') -Force
if ($Agent -and -not $Agents.Count) { $Agents = @($Agent.ToLowerInvariant()) }

if ($Verify) { $r = Test-SpecKitRadzenInstall -Repository $Repository; $r | Format-List Healthy, KitVersion, Agents, Problems | Out-String; if (-not $r.Healthy) { exit 1 }; return }
if ($Uninstall) { (Uninstall-SpecKitRadzen -Repository $Repository -Force:$Force -WhatIf:$WhatIfPreference).Summary; return }
if ($Update) { (Update-SpecKitRadzen -Repository $Repository -Source $dist -Agents $Agents -McpClient $McpClient -Force:$Force -EnableHooks:$EnableHooks -WhatIf:$WhatIfPreference).Summary; return }
(Install-SpecKitRadzen -Repository $Repository -Source $dist -Agents $Agents -McpClient $McpClient -Force:$Force -Yes:$Yes -EnableHooks:$EnableHooks -WhatIf:$WhatIfPreference).Summary
