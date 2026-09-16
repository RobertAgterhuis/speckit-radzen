function Uninstall-SpecKitRadzen {
    <#
    .SYNOPSIS
        Removes managed kit files, adapters, managed blocks, MCP entries and hooks that the installer added.
        Feature artifacts (specs/) and, by default, .speckit/radzen/local and config.json are kept.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Repository = (Get-Location).Path,
        [bool] $KeepLocal = $true,
        [switch] $Force
    )
    $repo = (Resolve-Path $Repository).Path
    $stateRoot = Join-Path $repo '.speckit' 'radzen'
    $manifest = Read-SkrJson -Path (Join-Path $stateRoot 'install-manifest.json') -AsHashtable
    if (-not $manifest) { throw 'Spec Kit Radzen is not installed (no install manifest).' }
    $ops = [System.Collections.Generic.List[object]]::new()
    $kept = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $manifest.files.Keys) {
        $path = Join-Path $repo $t
        if (-not (Test-Path $path)) { continue }
        if ($Force -or (Get-SkrContentHash -Path $path) -eq $manifest.files[$t].sha256) { $ops.Add(@{ Target = $t; Content = $null }) }
        else { $kept.Add($t) }
    }
    foreach ($b in $manifest.managedBlocks) {
        $path = Join-Path $repo $b
        if (-not (Test-Path $path)) { continue }
        $text = Merge-SkrManagedBlock -Existing ([System.IO.File]::ReadAllText($path)) -Body $null -TargetRelative $b
        $ops.Add(@{ Target = $b; Content = $(if ($text.Trim()) { $text } else { $null }) })
    }
    foreach ($client in @($manifest.mcpClients)) {
        $c = $script:SkrMcpClients[$client]
        if (-not $c) { continue }
        $path = Join-Path $repo $c.File
        if (-not (Test-Path $path)) { continue }
        $existing = [System.IO.File]::ReadAllText($path)
        $merged = if ($c.Format -eq 'json') { Merge-SkrMcpJson -Existing $existing -TemplateText '{}' -RootKey $c.RootKey -Remove } else { Merge-SkrMcpToml -Existing $existing -TemplateText '' -Remove }
        if ($null -ne $merged) {
            $empty = ($merged.Trim() -in '{}', '')
            $ops.Add(@{ Target = $c.File; Content = $(if ($empty) { $null } else { $merged }) })
        }
    }
    if ($manifest.hooks) {
        $settings = Join-Path $repo '.claude' 'settings.json'
        if (Test-Path $settings) {
            $cmd = 'pwsh -NoProfile -File .speckit/radzen/tools/speckit-radzen.ps1 scan'
            $template = (@{ hooks = @{ PostToolUse = @(@{ matcher = 'Edit|Write|MultiEdit'; hooks = @(@{ type = 'command'; command = $cmd }) }) } } | ConvertTo-Json -Depth 10)
            $merged = Merge-SkrClaudeHooks -Existing ([System.IO.File]::ReadAllText($settings)) -HooksText $template -Remove
            if ($null -ne $merged) { $ops.Add(@{ Target = '.claude/settings.json'; Content = $(if ($merged.Trim() -eq '{}') { $null } else { $merged }) }) }
        }
    }
    $generated = @('profile.json', 'profile.md', 'install-manifest.json')
    foreach ($g in $generated) { if (Test-Path (Join-Path $stateRoot $g)) { $ops.Add(@{ Target = ".speckit/radzen/$g"; Content = $null }) } }
    if (-not $KeepLocal) {
        foreach ($f in @(Get-ChildItem -Path (Join-Path $stateRoot 'local') -Recurse -File -ErrorAction Ignore) + @(Get-Item (Join-Path $stateRoot 'config.json') -ErrorAction Ignore)) {
            if ($f) { $ops.Add(@{ Target = (Get-SkrRelativePath -Base $repo -Path $f.FullName); Content = $null }) }
        }
    }
    $summary = "Uninstall Spec Kit Radzen $($manifest.kitVersion): $($ops.Count) operation(s)$(if ($kept.Count) { "; kept modified files: $($kept -join ', ')" }). specs/ is untouched$(if ($KeepLocal) { '; .speckit/radzen/local and config.json kept' })."
    if (-not $PSCmdlet.ShouldProcess($repo, $summary)) { return [pscustomobject]@{ Summary = "WhatIf: $summary"; Applied = $false } }
    $backupRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('skr-uninstall-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = Invoke-SkrInstallTransaction -Repository $repo -Operations $ops.ToArray() -BackupRoot $backupRoot
    Remove-Item $backupRoot -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($d in 'baseline', 'tmp', 'backup') { Remove-Item (Join-Path $stateRoot $d) -Recurse -Force -ErrorAction SilentlyContinue }
    Remove-SkrEmptyDirectory -Repository $repo -Paths @($ops | ForEach-Object { Join-Path $repo $_.Target })
    [pscustomobject]@{ Summary = $summary; Applied = $true; Kept = $kept.ToArray() }
}
