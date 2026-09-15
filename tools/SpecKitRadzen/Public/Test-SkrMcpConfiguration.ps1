function Test-SkrMcpConfiguration {
    <#
    .SYNOPSIS
        Checks Radzen MCP configuration in the repository (and user-level presence) without exposing secrets.
    .PARAMETER Probe
        Also calls the Radzen MCP endpoint using the RADZEN_MCP_KEY environment variable.
    .OUTPUTS
        Object with Status (available, configured, not-configured, unreachable, unauthorized, quota-exhausted, secret-in-repo) and per-file details.
    #>
    [CmdletBinding()]
    param(
        [string] $Repository = (Get-Location).Path,
        [switch] $Probe,
        [switch] $SkipUserLevel
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $details = [System.Collections.Generic.List[object]]::new()
    $secretInRepo = $false

    foreach ($client in $script:SkrMcpClients.Keys) {
        $c = $script:SkrMcpClients[$client]
        $path = Join-Path $repo $c.File
        if (-not (Test-Path $path)) { continue }
        $ignored = Test-SkrPathIgnored -Repository $repo -RelativePath $c.File
        foreach ($entry in @(Get-SkrMcpServerEntry -Path $path -Format $c.Format)) {
            $issue = $null
            if ($entry.Error) { $issue = "Cannot parse: $($entry.Error)" }
            elseif ($entry.KeyKind -eq 'literal') {
                if ($ignored) { $issue = 'Literal key in a git-ignored local file (acceptable; keep it ignored).' }
                else { $issue = 'Literal key in a file that is (or can be) committed.'; $secretInRepo = $true }
            }
            elseif ($entry.KeyKind -eq 'placeholder') { $issue = 'Key header contains a placeholder; replace it with a variable reference.' }
            elseif ($entry.KeyKind -eq 'absent' -and -not $entry.IsStudio) { $issue = "No $($script:SkrRadzenKeyHeader) header configured." }
            $details.Add([pscustomobject]@{
                    Scope = 'repository'; Client = $client; File = $c.File; Server = $entry.Name; Url = $entry.Url
                    Studio = $entry.IsStudio; KeyKind = $entry.KeyKind; GitIgnored = $ignored; Issue = $issue
                })
        }
    }

    if (-not $SkipUserLevel) {
        $userHome = [Environment]::GetFolderPath('UserProfile')
        $userFiles = @(
            @{ Client = 'ClaudeCode'; Path = (Join-Path $userHome '.claude.json'); Format = 'json' },
            @{ Client = 'VisualStudio'; Path = (Join-Path $userHome '.mcp.json'); Format = 'json' },
            @{ Client = 'Cursor'; Path = (Join-Path $userHome '.cursor' 'mcp.json'); Format = 'json' },
            @{ Client = 'Codex'; Path = (Join-Path $userHome '.codex' 'config.toml'); Format = 'toml' }
        )
        foreach ($u in $userFiles) {
            if (-not (Test-Path $u.Path)) { continue }
            $found = $false
            try {
                if ($u.Client -eq 'ClaudeCode') { $found = (Get-Content $u.Path -Raw) -match 'app\.radzen\.com/mcp' }
                else { $found = [bool]@(Get-SkrMcpServerEntry -Path $u.Path -Format $u.Format | Where-Object { -not $_.Error }).Count }
            }
            catch { $found = $false }
            if ($found) {
                $details.Add([pscustomobject]@{ Scope = 'user'; Client = $u.Client; File = $u.Path; Server = 'radzen'; Url = $null; Studio = $false; KeyKind = 'user-level'; GitIgnored = $true; Issue = $null })
            }
        }
    }

    $envSet = [bool][Environment]::GetEnvironmentVariable($script:SkrRadzenKeyEnv)
    $blazorServers = @($details | Where-Object { -not $_.Studio })
    $status = if ($secretInRepo) { 'secret-in-repo' }
    elseif ($blazorServers.Count) { 'configured' }
    else { 'not-configured' }

    $probeResult = $null
    if ($Probe -and $status -ne 'secret-in-repo') {
        $probeResult = Invoke-SkrMcpProbe
        if ($probeResult.Status -ne 'not-configured' -or $status -eq 'not-configured') { $status = $probeResult.Status }
    }

    $advice = switch ($status) {
        'secret-in-repo' { 'Remove the literal key, rotate it, and use the RADZEN_MCP_KEY environment variable or a client input prompt (see mcp/README.md).' }
        'not-configured' { 'Configure the Radzen Blazor MCP (installer -McpClient, or mcp/templates). Until then follow core/mcp/fallback-matrix.md.' }
        'configured' { if ($envSet) { 'Configured. Run with -Probe to verify the key, and confirm the Radzen tool is listed in your agent.' } else { "Configured, but $($script:SkrRadzenKeyEnv) is not set in this process (fine if the client uses an input prompt or user-level config)." } }
        'available' { 'Endpoint reachable and key accepted.' }
        'unauthorized' { 'Key rejected. Check the key and licence (trial quota, Pro/Team).' }
        'unreachable' { 'Endpoint not reachable from this machine (network/proxy). Follow the fallback matrix.' }
        'quota-exhausted' { 'Request limit reached. Reuse evidence; follow the fallback matrix.' }
        default { '' }
    }

    [pscustomobject]@{
        Status        = $status
        KeyEnvVarSet  = $envSet
        Probe         = $probeResult
        Servers       = $details.ToArray()
        Advice        = $advice
    }
}
