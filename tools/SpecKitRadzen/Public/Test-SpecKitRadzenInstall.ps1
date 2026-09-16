function Test-SpecKitRadzenInstall {
    <#
    .SYNOPSIS
        Verifies installed managed files against the install manifest.
    #>
    [CmdletBinding()]
    param([string] $Repository = (Get-Location).Path)
    $repo = Resolve-SkrRepository -Path $Repository
    $manifest = Read-SkrJson -Path (Join-Path (Get-SkrStateRoot $repo) 'install-manifest.json') -AsHashtable
    if (-not $manifest) {
        return [pscustomobject]@{ Healthy = $false; KitVersion = $null; Agents = @(); Problems = @('Not installed (no .speckit/radzen/install-manifest.json).'); Modified = @(); Missing = @() }
    }
    $missing = [System.Collections.Generic.List[string]]::new()
    $modified = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $manifest.files.Keys) {
        $path = Join-Path $repo $t
        if (-not (Test-Path $path -PathType Leaf)) { $missing.Add($t); continue }
        if ((Get-SkrContentHash -Path $path) -ne $manifest.files[$t].sha256) { $modified.Add($t) }
    }
    $blocks = [System.Collections.Generic.List[string]]::new()
    foreach ($b in $manifest.managedBlocks) {
        $path = Join-Path $repo $b
        if (-not (Test-Path $path) -or ([System.IO.File]::ReadAllText($path) -notmatch 'speckit-radzen:begin')) { $blocks.Add($b) }
    }
    $problems = @()
    $problems += @($missing | ForEach-Object { "missing: $_" })
    $problems += @($modified | ForEach-Object { "modified: $_ (move changes to .speckit/radzen/local/ or re-run update -Force)" })
    $problems += @($blocks | ForEach-Object { "managed block missing: $_" })
    $pending = @(Get-ChildItem -Path $repo -Recurse -Force -File -Filter '*.speckit-new' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|bin|obj)[\\/]' -and $_.FullName -notmatch '[\\/]\.speckit[\\/]radzen[\\/]backup[\\/]' } | ForEach-Object { Get-SkrRelativePath -Base $repo -Path $_.FullName })
    $problems += @($pending | ForEach-Object { "unmerged update: $_" })
    [pscustomobject]@{
        Healthy = -not $problems.Count; KitVersion = $manifest.kitVersion; Agents = @($manifest.agents)
        Problems = $problems; Modified = $modified.ToArray(); Missing = $missing.ToArray()
    }
}
