function Install-SpecKitRadzen {
    <#
    .SYNOPSIS
        Installs (or updates) Spec Kit Radzen into a repository: kit files, agent adapters, managed instruction blocks and optional MCP configuration.
    .PARAMETER Agents
        claude, copilot, codex, cursor, generic. Empty = auto-detect from the repository (or, on update, the agents already installed).
    .PARAMETER McpClient
        ClaudeCode, VSCode, VisualStudio, Cursor, Codex — adds the radzen-blazor server (no key) to that client's repository config.
    .PARAMETER Source
        Distribution root to install from (default: the distribution this module belongs to).
    .PARAMETER Force
        Overwrite locally modified managed files and existing user files (backed up first).
    .PARAMETER Yes
        Do not ask for confirmation of auto-detected agents.
    .PARAMETER EnableHooks
        Claude Code: merge a PostToolUse hook that runs the anti-pattern scan after edits into .claude/settings.json.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Repository = (Get-Location).Path,
        [string[]] $Agents = @(),
        [string[]] $McpClient = @(),
        [string] $Source,
        [switch] $Force,
        [switch] $Yes,
        [switch] $EnableHooks,
        [switch] $Update
    )
    if (-not (Test-Path $Repository -PathType Container)) { throw "Repository '$Repository' does not exist." }
    $repo = (Resolve-Path $Repository).Path
    $sourceRoot = if ($Source) { (Resolve-Path $Source).Path } else { Get-SkrKitRoot }
    foreach ($required in 'core', 'tools', 'integrations') {
        if (-not (Test-Path (Join-Path $sourceRoot $required))) { throw "'$sourceRoot' is not a Spec Kit Radzen distribution (missing $required/)." }
    }
    if ([System.IO.Path]::GetFullPath($sourceRoot).TrimEnd('/', '\') -eq [System.IO.Path]::GetFullPath((Join-Path $repo '.speckit' 'radzen')).TrimEnd('/', '\')) {
        throw 'The source is the installed kit itself. Pass -Source <path to the new distribution>.'
    }
    $version = (Get-Content (Join-Path $sourceRoot 'VERSION') -Raw).Trim()
    $stateRoot = Join-Path $repo '.speckit' 'radzen'
    $manifestPath = Join-Path $stateRoot 'install-manifest.json'
    $old = Read-SkrJson -Path $manifestPath -AsHashtable
    $isV1 = (-not $old) -and (Test-Path (Join-Path $stateRoot 'core'))

    if ($old -and -not $Update -and -not $Force) { throw "Spec Kit Radzen $($old.kitVersion) is already installed. Use Update-SpecKitRadzen (CLI: update) or -Force." }
    if ($Update -and -not $old -and -not $isV1) { throw 'Spec Kit Radzen is not installed in this repository. Use Install-SpecKitRadzen.' }

    # ---- agents ----
    $Agents = @($Agents | ForEach-Object { "$_".ToLowerInvariant() } | Where-Object { $_ })
    if ($Agents -contains 'all') { $Agents = @('claude', 'copilot', 'codex', 'cursor') }
    if ($Agents -contains 'auto') { $Agents = @() }
    $detected = $false
    if (-not $Agents.Count) {
        if ($old) { $Agents = @($old.agents) }
        else { $Agents = @(Get-SkrDetectedAgent -Repository $repo); $detected = $true }
    }
    foreach ($a in $Agents) { if ($script:SkrAgents -notcontains $a) { throw "Unknown agent '$a'. Valid: $($script:SkrAgents -join ', ')." } }
    $Agents = @($script:SkrAgents | Where-Object { $Agents -contains $_ })
    if ($detected -and -not $Yes -and -not $WhatIfPreference) {
        Write-Host "Detected agent environment: $($Agents -join ', ')"
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $answer = Read-Host 'Install these adapters? [Y/n or comma-separated list]'
            if ($answer -match '^(n|no)$') { throw 'Installation cancelled.' }
            if ($answer -and $answer -notmatch '^(y|yes)$') { $Agents = @($answer -split '\s*,\s*' | Where-Object { $_ }) ; foreach ($a in $Agents) { if ($script:SkrAgents -notcontains $a) { throw "Unknown agent '$a'." } } }
        }
    }

    $plan = Get-SkrInstallPlan -SourceRoot $sourceRoot -Agents $Agents -Version $version
    $oldFiles = if ($old) { $old.files } else { @{} }
    $operations = [System.Collections.Generic.List[object]]::new()
    $newFiles = [ordered]@{}
    $kept = [System.Collections.Generic.List[string]]::new()
    $conflicts = [System.Collections.Generic.List[string]]::new()
    $blocks = [System.Collections.Generic.List[string]]::new()
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $hashOf = {
        param([string] $text)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { [System.Convert]::ToHexString($sha.ComputeHash($utf8.GetBytes(((($text.TrimStart([char]0xFEFF)) -replace "`r`n", "`n").TrimEnd("`n") + "`n")))).ToLowerInvariant() } finally { $sha.Dispose() }
    }

    foreach ($item in $plan.Values) {
        $path = Join-Path $repo $item.Target
        if ($item.Kind -eq 'block') {
            $existing = if (Test-Path $path) { [System.IO.File]::ReadAllText($path) } else { $null }
            $merged = Merge-SkrManagedBlock -Existing $existing -Body $item.Content -TargetRelative $item.Target -Version $version
            if ($merged -ne $existing) { $operations.Add(@{ Target = $item.Target; Content = $merged }) }
            $blocks.Add($item.Target)
            continue
        }
        $desiredHash = & $hashOf $item.Content
        $newFiles[$item.Target] = @{ sha256 = $desiredHash; owner = $item.Owner }
        if (-not (Test-Path $path -PathType Leaf)) { $operations.Add(@{ Target = $item.Target; Content = $item.Content }); continue }
        $currentHash = Get-SkrContentHash -Path $path
        if ($currentHash -eq $desiredHash) { continue }
        $tracked = $oldFiles.ContainsKey($item.Target)
        $unmodified = $tracked -and $oldFiles[$item.Target].sha256 -eq $currentHash
        if ($unmodified -or $Force -or ($isV1 -and $item.Target.StartsWith('.speckit/radzen/'))) {
            $operations.Add(@{ Target = $item.Target; Content = $item.Content })
        }
        elseif ($tracked) {
            $operations.Add(@{ Target = "$($item.Target).speckit-new"; Content = $item.Content })
            $kept.Add($item.Target)
            $newFiles[$item.Target] = $oldFiles[$item.Target]   # keep tracking the user's version
        }
        else { $conflicts.Add($item.Target) }
    }
    if ($conflicts.Count) {
        throw "These files already exist and are not managed by Spec Kit Radzen: $($conflicts -join ', '). Move them, or re-run with -Force (they are backed up)."
    }

    # files removed from the kit since the previous version
    foreach ($t in @($oldFiles.Keys)) {
        if ($newFiles.Contains($t)) { continue }
        $path = Join-Path $repo $t
        if (-not (Test-Path $path)) { continue }
        if ((Get-SkrContentHash -Path $path) -eq $oldFiles[$t].sha256 -or $Force) { $operations.Add(@{ Target = $t; Content = $null }) }
        else { $kept.Add("$t (obsolete, locally modified — kept)") }
    }
    # managed blocks from agents that are no longer installed
    foreach ($b in @(if ($old) { $old.managedBlocks })) {
        if ($blocks -contains $b) { continue }
        $path = Join-Path $repo $b
        if (Test-Path $path) { $operations.Add(@{ Target = $b; Content = (Merge-SkrManagedBlock -Existing ([System.IO.File]::ReadAllText($path)) -Body $null -TargetRelative $b) }) }
    }
    # V1 leftovers inside the kit folder
    if ($isV1) {
        foreach ($f in Get-ChildItem -Path (Join-Path $stateRoot 'core') -Recurse -File) {
            $rel = '.speckit/radzen/core/' + (Get-SkrRelativePath -Base (Join-Path $stateRoot 'core') -Path $f.FullName)
            if (-not $plan.Contains($rel)) { $operations.Add(@{ Target = $rel; Content = $null }) }
        }
    }

    # ---- MCP clients ----
    $mcpDone = [System.Collections.Generic.List[string]]::new()
    foreach ($client in $McpClient) {
        $key = @($script:SkrMcpClients.Keys | Where-Object { $_ -ieq $client })[0]
        if (-not $key) { throw "Unknown MCP client '$client'. Valid: $($script:SkrMcpClients.Keys -join ', ')." }
        $c = $script:SkrMcpClients[$key]
        $path = Join-Path $repo $c.File
        $existing = if (Test-Path $path) { [System.IO.File]::ReadAllText($path) } else { $null }
        $template = [System.IO.File]::ReadAllText((Join-Path $sourceRoot 'mcp' 'templates' $c.Template))
        $merged = if ($c.Format -eq 'json') { Merge-SkrMcpJson -Existing $existing -TemplateText $template -RootKey $c.RootKey -Force:$Force } else { Merge-SkrMcpToml -Existing $existing -TemplateText $template }
        if ($null -ne $merged) { $operations.Add(@{ Target = $c.File; Content = $merged }) }
        $mcpDone.Add($key)
    }
    if ($old -and $old.mcpClients) { foreach ($m in $old.mcpClients) { if (-not $mcpDone.Contains($m)) { $mcpDone.Add($m) } } }

    # ---- hooks ----
    $hooks = [bool]($old -and $old.hooks)
    if ($EnableHooks) {
        if ($Agents -notcontains 'claude') { throw '-EnableHooks requires the claude adapter.' }
        $settings = Join-Path $repo '.claude' 'settings.json'
        $existing = if (Test-Path $settings) { [System.IO.File]::ReadAllText($settings) } else { $null }
        $merged = Merge-SkrClaudeHooks -Existing $existing -HooksText ([System.IO.File]::ReadAllText((Join-Path $sourceRoot 'integrations' 'claude' 'dot-claude' 'speckit-radzen.hooks.json')))
        if ($null -ne $merged) { $operations.Add(@{ Target = '.claude/settings.json'; Content = $merged }) }
        $hooks = $true
    }

    # local folder (user-owned, never tracked)
    $localReadme = Join-Path $stateRoot 'local' 'README.md'
    if (-not (Test-Path $localReadme)) {
        $operations.Add(@{ Target = '.speckit/radzen/local/README.md'; Content = "# Local amendments`n`nRepository-specific additions to Spec Kit Radzen. Upgrades never touch this folder.`n`n- constitution.local.md — tightened or added principles`n- antipatterns.local.json — extra scanner rules`n- detection-rules.local.json — extra detection rules`n- standards/*.md — house standards`n" })
    }

    $now = Get-SkrTimestamp
    $manifest = [ordered]@{
        schemaVersion = 1; kitVersion = $version
        installedAt = if ($old) { $old.installedAt } else { $now }; updatedAt = $now
        agents = @($Agents); mcpClients = @($mcpDone); hooks = $hooks
        files = $newFiles; managedBlocks = @($blocks)
    }
    $operations.Add(@{ Target = '.speckit/radzen/install-manifest.json'; Content = ($manifest | ConvertTo-Json -Depth 10) })

    $action = if ($Update -or $old -or $isV1) { 'Update' } else { 'Install' }
    $summaryLines = @(
        "$action Spec Kit Radzen $version into $repo",
        "  agents: $($Agents -join ', ')$(if ($detected) { ' (auto-detected)' })",
        "  changes: $($operations.Count) file operation(s)",
        $(if ($mcpDone.Count) { "  MCP clients: $($mcpDone -join ', ') (set RADZEN_MCP_KEY; see .speckit/radzen/core/mcp/)" }),
        $(if ($kept.Count) { "  kept local edits (new versions written as *.speckit-new): $($kept -join ', ')" }),
        $(if ($isV1) { '  migrated from V1: previous core backed up' }),
        '  next: pwsh .speckit/radzen/tools/speckit-radzen.ps1 detect'
    ) | Where-Object { $_ }

    if (-not $PSCmdlet.ShouldProcess($repo, "$action Spec Kit Radzen $version ($($operations.Count) operations)")) {
        return [pscustomobject]@{ Summary = (@('WhatIf:') + $summaryLines) -join "`n"; Operations = @($operations | ForEach-Object { if ($null -eq $_.Content) { "delete $($_.Target)" } else { "write $($_.Target)" } }); Agents = $Agents; Applied = $false }
    }
    $backupRoot = Join-Path $stateRoot 'backup' ((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
    $null = Invoke-SkrInstallTransaction -Repository $repo -Operations $operations.ToArray() -BackupRoot $backupRoot
    if (Test-Path $backupRoot) {
        if (-not ($isV1 -or $Force -or $kept.Count)) { Remove-Item $backupRoot -Recurse -Force -ErrorAction SilentlyContinue }
        else { $summaryLines += "  backup: $(Get-SkrRelativePath -Base $repo -Path $backupRoot)" }
    }
    Remove-SkrEmptyDirectory -Repository $repo -Paths @($operations | Where-Object { $null -eq $_.Content } | ForEach-Object { Join-Path $repo $_.Target })
    [pscustomobject]@{ Summary = $summaryLines -join "`n"; Agents = $Agents; McpClients = @($mcpDone); Kept = $kept.ToArray(); Operations = $operations.Count; Applied = $true; Version = $version }
}
