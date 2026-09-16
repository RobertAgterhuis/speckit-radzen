# Installer internals: planning, managed blocks, MCP merge, atomic apply.

$script:SkrAgents = @('claude', 'copilot', 'codex', 'cursor', 'generic')
$script:SkrBlockBegin = 'speckit-radzen:begin'
$script:SkrBlockEnd = 'speckit-radzen:end'

function Get-SkrDetectedAgent {
    param([Parameter(Mandatory)][string] $Repository)
    $has = { param($rel) Test-Path (Join-Path $Repository $rel) }
    $found = [System.Collections.Generic.List[string]]::new()
    if ((& $has '.claude') -or (& $has 'CLAUDE.md') -or (& $has '.mcp.json')) { $found.Add('claude') }
    if ((& $has '.github/copilot-instructions.md') -or (& $has '.github/instructions') -or (& $has '.github/prompts') -or (& $has '.github/agents') -or (& $has '.vscode/mcp.json')) { $found.Add('copilot') }
    if ((& $has 'AGENTS.md') -or (& $has '.codex')) { $found.Add('codex') }
    if ((& $has '.cursor') -or (& $has '.cursorrules')) { $found.Add('cursor') }
    if (-not $found.Count) { $found.Add('generic') }
    return $found.ToArray()
}

function ConvertTo-SkrTargetPath {
    <# integrations/<agent>/dot-claude/x -> .claude/x #>
    param([Parameter(Mandatory)][string] $Relative)
    return (($Relative -split '/') | ForEach-Object { if ($_ -match '^dot-(.+)$') { ".$($Matches[1])" } else { $_ } }) -join '/'
}

function Get-SkrBlockMarker {
    param([Parameter(Mandatory)][string] $TargetRelative, [string] $Version)
    if ($TargetRelative -match '(^|/)\.gitignore$') { return @("# $($script:SkrBlockBegin) $Version", "# $($script:SkrBlockEnd)") }
    return @("<!-- $($script:SkrBlockBegin) $Version -->", "<!-- $($script:SkrBlockEnd) -->")
}

function Merge-SkrManagedBlock {
    <# Returns new file text with the managed block inserted/replaced. $Body = $null removes the block. #>
    param([AllowEmptyString()][AllowNull()][string] $Existing, [AllowNull()][object] $Body, [Parameter(Mandatory)][string] $TargetRelative, [string] $Version)
    $markers = Get-SkrBlockMarker -TargetRelative $TargetRelative -Version $Version
    $text = if ($null -eq $Existing) { '' } else { $Existing -replace "`r`n", "`n" }
    $pattern = '(?ms)^[^\n]*' + [regex]::Escape($script:SkrBlockBegin) + '[^\n]*\n.*?^[^\n]*' + [regex]::Escape($script:SkrBlockEnd) + '[^\n]*\n?'
    $block = if ($null -ne $Body) { "$($markers[0])`n$(([string]$Body).Trim())`n$($markers[1])`n" } else { '' }
    if ([regex]::IsMatch($text, $pattern)) {
        $text = [regex]::Replace($text, $pattern, { param($m) $block }, 1)
    }
    elseif ($null -ne $Body) {
        if ($text.Length -and -not $text.EndsWith("`n")) { $text += "`n" }
        if ($text.Length) { $text += "`n" }
        $text += $block
    }
    $text = [regex]::Replace($text, "\n{3,}", "`n`n")
    if ($null -eq $Body -and $text.Trim().Length) { $text = $text.TrimEnd() + "`n" }
    return $text
}

function Merge-SkrMcpJson {
    <# Adds (or with -Remove removes) the radzen-blazor server in a JSON MCP config. Returns $null when nothing changes. #>
    param([AllowNull()][string] $Existing, [AllowEmptyString()][string] $TemplateText, [Parameter(Mandatory)][string] $RootKey, [switch] $Remove, [switch] $Force)
    $template = if ($TemplateText) { $TemplateText | ConvertFrom-Json -AsHashtable -Depth 32 } else { @{} }
    $doc = if ($Existing) { $Existing | ConvertFrom-Json -AsHashtable -Depth 32 } else { [ordered]@{} }
    if (-not $doc) { $doc = [ordered]@{} }
    if ($Remove) {
        if (-not $doc.Contains($RootKey) -or -not $doc[$RootKey].Contains('radzen-blazor')) { return $null }
        $entry = $doc[$RootKey]['radzen-blazor']
        $key = if ($entry.headers) { [string]$entry.headers['X-Radzen-Key'] } else { '' }
        if (-not (Test-SkrSecretReference $key)) { return $null }   # never delete a user-authored literal config
        $doc[$RootKey].Remove('radzen-blazor')
        if ($doc.Contains('inputs')) { $doc['inputs'] = @($doc['inputs'] | Where-Object { $_.id -ne 'radzen-key' }) ; if (-not $doc['inputs'].Count) { $doc.Remove('inputs') } }
        if (-not $doc[$RootKey].Count) { $doc.Remove($RootKey) }
        return ($doc | ConvertTo-Json -Depth 32)
    }
    if (-not $doc.Contains($RootKey)) { $doc[$RootKey] = [ordered]@{} }
    if ($doc[$RootKey].Contains('radzen-blazor') -and -not $Force) { return $null }
    $doc[$RootKey]['radzen-blazor'] = $template[$RootKey]['radzen-blazor']
    if ($template.Contains('inputs')) {
        $inputs = @(if ($doc.Contains('inputs')) { $doc['inputs'] })
        if (-not ($inputs | Where-Object { $_.id -eq 'radzen-key' })) { $inputs += $template['inputs'] }
        $doc['inputs'] = $inputs
    }
    return ($doc | ConvertTo-Json -Depth 32)
}

function Merge-SkrMcpToml {
    param([AllowNull()][string] $Existing, [AllowEmptyString()][string] $TemplateText, [switch] $Remove)
    $text = if ($Existing) { $Existing -replace "`r`n", "`n" } else { '' }
    $has = $text -match '(?m)^\[mcp_servers\.radzen-blazor\]'
    if ($Remove) {
        if (-not $has) { return $null }
        return (Merge-SkrManagedBlock -Existing $text -Body $null -TargetRelative 'config.toml')
    }
    if ($has) { return $null }
    $body = ($TemplateText -replace "`r`n", "`n").Trim()
    $lines = ($body -split "`n") | ForEach-Object { $_ }
    $block = "# $($script:SkrBlockBegin)`n$(($lines) -join "`n")`n# $($script:SkrBlockEnd)`n"
    if ($text.Length -and -not $text.EndsWith("`n")) { $text += "`n" }
    if ($text.Length) { $text += "`n" }
    return $text + $block
}

function Merge-SkrClaudeHooks {
    param([AllowNull()][string] $Existing, [Parameter(Mandatory)][string] $HooksText, [switch] $Remove)
    $doc = if ($Existing) { $Existing | ConvertFrom-Json -AsHashtable -Depth 32 } else { [ordered]@{} }
    $ours = ($HooksText | ConvertFrom-Json -AsHashtable -Depth 32).hooks.PostToolUse[0]
    $command = $ours.hooks[0].command
    if (-not $doc.Contains('hooks')) { $doc['hooks'] = [ordered]@{} }
    $list = @(if ($doc['hooks'].Contains('PostToolUse')) { $doc['hooks']['PostToolUse'] })
    $isOurs = { param($e) @($e.hooks | Where-Object { $_.command -eq $command }).Count -gt 0 }
    if ($Remove) {
        $filtered = @($list | Where-Object { -not (& $isOurs $_) })
        if ($filtered.Count -eq $list.Count) { return $null }
        if ($filtered.Count) { $doc['hooks']['PostToolUse'] = $filtered } else { $doc['hooks'].Remove('PostToolUse') }
        if (-not $doc['hooks'].Count) { $doc.Remove('hooks') }
        return ($doc | ConvertTo-Json -Depth 32)
    }
    if (@($list | Where-Object { & $isOurs $_ }).Count) { return $null }
    $doc['hooks']['PostToolUse'] = @($list) + @($ours)
    return ($doc | ConvertTo-Json -Depth 32)
}

function Get-SkrInstallPlan {
    <# Builds the list of desired files: @{ Target; Content (string); Owner; Kind = file|block } #>
    param([Parameter(Mandatory)][string] $SourceRoot, [Parameter(Mandatory)][string[]] $Agents, [string] $Version)
    $plan = [ordered]@{}
    $addFile = {
        param($target, $sourcePath, $owner)
        $content = [System.IO.File]::ReadAllText($sourcePath)
        if ($plan.Contains($target)) {
            if (($plan[$target].Content -replace "`r`n", "`n") -ne ($content -replace "`r`n", "`n")) { throw "Adapter conflict: $target is produced with different content by $($plan[$target].Owner) and $owner." }
            if ($plan[$target].Owner -notmatch "\b$owner\b") { $plan[$target].Owner += ",$owner" }
            return
        }
        $plan[$target] = @{ Target = $target; Content = $content; Owner = $owner; Kind = 'file' }
    }
    foreach ($folder in 'core', 'tools') {
        $root = Join-Path $SourceRoot $folder
        foreach ($f in Get-ChildItem -Path $root -Recurse -File -Force) {
            $rel = Get-SkrRelativePath -Base $root -Path $f.FullName
            if ($rel -match '(^|/)(bin|obj)/') { continue }
            & $addFile ".speckit/radzen/$folder/$rel" $f.FullName 'kit'
        }
    }
    foreach ($f in Get-ChildItem -Path (Join-Path $SourceRoot 'mcp' 'templates') -File) { & $addFile ".speckit/radzen/mcp/templates/$($f.Name)" $f.FullName 'kit' }
    $versionFile = Join-Path $SourceRoot 'VERSION'
    if (Test-Path $versionFile) { & $addFile '.speckit/radzen/VERSION' $versionFile 'kit' }
    foreach ($agent in $Agents) {
        $root = Join-Path $SourceRoot 'integrations' $agent
        if (-not (Test-Path $root)) { throw "Adapter '$agent' not found in $SourceRoot/integrations." }
        foreach ($f in Get-ChildItem -Path $root -Recurse -File -Force) {
            $rel = ConvertTo-SkrTargetPath (Get-SkrRelativePath -Base $root -Path $f.FullName)
            if ($rel -eq '.claude/speckit-radzen.hooks.json') { continue }   # merged only with -EnableHooks
            if ($rel.EndsWith('.block')) {
                $target = $rel.Substring(0, $rel.Length - 6)
                $plan[$target] = @{ Target = $target; Content = [System.IO.File]::ReadAllText($f.FullName); Owner = $agent; Kind = 'block' }
            }
            else { & $addFile $rel $f.FullName $agent }
        }
    }
    $plan['.gitignore'] = @{ Target = '.gitignore'; Content = ".speckit/radzen/tmp/`n.speckit/radzen/backup/`n*.speckit-new"; Owner = 'kit'; Kind = 'block' }
    return $plan
}

function Invoke-SkrInstallTransaction {
    <#
    Applies a list of writes/deletes atomically: every touched path is backed up first; on failure all changes are rolled back.
    $Operations: @{ Target (relative); Content (string, $null = delete) }
    #>
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][object[]] $Operations, [Parameter(Mandatory)][string] $BackupRoot)
    $journal = [System.Collections.Generic.List[object]]::new()
    $failAfter = [int]([Environment]::GetEnvironmentVariable('SKR_INSTALL_FAIL_AFTER') -as [int])
    $count = 0
    try {
        foreach ($op in $Operations) {
            $path = Join-Path $Repository $op.Target
            $existed = Test-Path $path -PathType Leaf
            $backup = $null
            if ($existed) {
                $backup = Join-Path $BackupRoot $op.Target
                $null = New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent)
                Copy-Item -LiteralPath $path -Destination $backup -Force
            }
            $journal.Add(@{ Path = $path; Existed = $existed; Backup = $backup })
            if ($null -eq $op.Content) { if ($existed) { Remove-Item -LiteralPath $path -Force } }
            else {
                $dir = Split-Path $path -Parent
                if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Force -Path $dir }
                $text = $op.Content
                if ($op.Target -match '\.(ps1|psm1|psd1)$') { $text = ($text -replace "`r?`n", "`r`n") ; [System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($false)) }
                else { Write-SkrText -Path $path -Content $text }
            }
            $count++
            if ($failAfter -gt 0 -and $count -ge $failAfter) { throw "Simulated failure after $count operation(s) (SKR_INSTALL_FAIL_AFTER)." }
        }
    }
    catch {
        for ($i = $journal.Count - 1; $i -ge 0; $i--) {
            $j = $journal[$i]
            try {
                if ($j.Existed) { Copy-Item -LiteralPath $j.Backup -Destination $j.Path -Force }
                elseif (Test-Path $j.Path) { Remove-Item -LiteralPath $j.Path -Force }
            }
            catch { Write-Warning "Rollback failed for $($j.Path): $_" }
        }
        Remove-SkrEmptyDirectory -Repository $Repository -Paths @($journal | ForEach-Object { $_.Path })
        throw "Installation rolled back: $($_.Exception.Message)"
    }
    return $journal.Count
}

function Remove-SkrEmptyDirectory {
    param([Parameter(Mandatory)][string] $Repository, [string[]] $Paths)
    $repoFull = [System.IO.Path]::GetFullPath($Repository).TrimEnd('/', '\')
    foreach ($p in $Paths) {
        $dir = Split-Path $p -Parent
        while ($dir -and ([System.IO.Path]::GetFullPath($dir).TrimEnd('/', '\') -ne $repoFull) -and (Test-Path $dir)) {
            if (@(Get-ChildItem -LiteralPath $dir -Force).Count) { break }
            Remove-Item -LiteralPath $dir -Force
            $dir = Split-Path $dir -Parent
        }
    }
}
