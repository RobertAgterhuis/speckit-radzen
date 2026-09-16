function Update-SpecKitRadzen {
    <#
    .SYNOPSIS
        Updates an installed kit (or migrates a V1 install) from a newer distribution. Locally modified files are kept; the new version is written next to them as *.speckit-new.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Repository = (Get-Location).Path,
        [string] $Source,
        [string[]] $Agents = @(),
        [string[]] $McpClient = @(),
        [switch] $Force,
        [switch] $EnableHooks
    )
    Install-SpecKitRadzen -Repository $Repository -Source $Source -Agents $Agents -McpClient $McpClient -Force:$Force -EnableHooks:$EnableHooks -Update -Yes -WhatIf:$WhatIfPreference
}
