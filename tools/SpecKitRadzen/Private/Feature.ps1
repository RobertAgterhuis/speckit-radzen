# Feature folder, state and fingerprint helpers.

$script:SkrPhases = @('bootstrap', 'discover', 'specify', 'clarify', 'plan', 'tasks', 'analyze', 'implement', 'review', 'done')

# Gate that must have passed before entering a phase.
$script:SkrPhaseEntryGate = @{
    discover  = 'G0'
    specify   = 'G1'
    plan      = 'G2'
    tasks     = 'G3'
    implement = 'G4'
    done      = 'G8'
}

function Get-SkrSpecsRoot {
    param([Parameter(Mandatory)][string] $Repository)
    $config = Get-SkrConfig -Repository $Repository
    $dir = if ($config.specsDirectory) { $config.specsDirectory } else { 'specs' }
    return (Join-Path $Repository $dir)
}

function ConvertTo-SkrSlug {
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Name)
    $normalized = $Name.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $normalized.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) { $null = $sb.Append($ch) }
    }
    $slug = ($sb.ToString().ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 48) { $slug = $slug.Substring(0, 48).Trim('-') }
    if (-not $slug) { throw "Feature name '$Name' does not contain any usable characters." }
    return $slug
}

function Get-SkrFeatureFolder {
    param([Parameter(Mandatory)][string] $Repository)
    $root = Get-SkrSpecsRoot -Repository $Repository
    if (-not (Test-Path $root)) { return @() }
    return @(Get-ChildItem -Path $root -Directory | Where-Object Name -Match '^[0-9]{3}-' | Sort-Object Name)
}

function Resolve-SkrFeature {
    <# Resolves -Feature (number, full folder name, or slug) to the feature folder. Without a value, returns the highest-numbered feature that is not done. #>
    param([Parameter(Mandatory)][string] $Repository, [string] $Feature)
    $folders = Get-SkrFeatureFolder -Repository $Repository
    if (-not $folders) { throw "No features found under '$(Get-SkrSpecsRoot -Repository $Repository)'. Run 'speckit-radzen new-feature'." }
    $match = $null
    if ($Feature) {
        $match = $folders | Where-Object { $_.Name -eq $Feature -or $_.Name.StartsWith("$Feature-") -or $_.Name.Substring(4) -eq $Feature }
        if (-not $match) { throw "Feature '$Feature' not found. Known features: $($folders.Name -join ', ')" }
        if (@($match).Count -gt 1) { throw "Feature '$Feature' is ambiguous: $(@($match).Name -join ', ')" }
    }
    else {
        $open = $folders | Where-Object {
            $s = Read-SkrJson -Path (Join-Path $_.FullName 'state.json')
            -not $s -or $s.phase -ne 'done'
        }
        $match = if ($open) { @($open)[-1] } else { @($folders)[-1] }
    }
    $folder = @($match)[0]
    [pscustomobject]@{
        Id     = $folder.Name
        Number = $folder.Name.Substring(0, 3)
        Path   = $folder.FullName
    }
}

function Get-SkrState {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $state = Read-SkrJson -Path (Join-Path $FeaturePath 'state.json') -AsHashtable
    if (-not $state) { throw "state.json missing in '$FeaturePath'." }
    foreach ($key in 'gates', 'slices', 'mcp') { if (-not $state.ContainsKey($key) -or $null -eq $state[$key]) { $state[$key] = @{} } }
    if (-not $state.ContainsKey('history') -or $null -eq $state.history) { $state.history = @() }
    return $state
}

function Save-SkrState {
    param([Parameter(Mandatory)][string] $FeaturePath, [Parameter(Mandatory)][hashtable] $State, [string] $EventName, [string] $Detail)
    $now = Get-SkrTimestamp
    $State.updated = $now
    if ($EventName) {
        $State.history = @($State.history) + @([ordered]@{ at = $now; event = $EventName; detail = $Detail })
    }
    $ordered = [ordered]@{}
    foreach ($k in 'schemaVersion', 'feature', 'number', 'name', 'phase', 'created', 'updated', 'baseRef', 'mcp', 'gates', 'slices', 'history') {
        if ($State.ContainsKey($k)) { $ordered[$k] = $State[$k] }
    }
    $json = $ordered | ConvertTo-Json -Depth 20
    $errors = Test-SkrJsonSchema -Json $json -SchemaName 'state'
    if ($errors.Count) { throw "Refusing to write invalid state.json: $($errors -join '; ')" }
    Write-SkrText -Path (Join-Path $FeaturePath 'state.json') -Content $json
}

function Get-SkrCodeFingerprint {
    <#
    Fingerprint of the code under change. With git: HEAD + working-tree diff + untracked files.
    Without git: content hash of source files. Feature artifacts (specs/) and kit state (.speckit/) are excluded,
    so editing artifacts never invalidates code gates.
    #>
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Repository)
    $specsRel = Get-SkrRelativePath -Base $Repository -Path (Get-SkrSpecsRoot -Repository $Repository)
    $sb = [System.Text.StringBuilder]::new()
    $useGit = (Get-Command git -ErrorAction Ignore) -and (Test-Path (Join-Path $Repository '.git'))
    if ($useGit) {
        $head = & git -C $Repository rev-parse HEAD 2>$null
        $null = $sb.AppendLine("HEAD:$head")
        $pathspec = @('--', '.', ":(exclude)$specsRel", ':(exclude).speckit')
        $diff = & git -C $Repository diff HEAD --no-color @pathspec 2>$null
        if ($LASTEXITCODE -ne 0) { $diff = & git -C $Repository diff --no-color @pathspec 2>$null }
        $null = $sb.AppendLine(($diff -join "`n"))
        $untracked = & git -C $Repository ls-files --others --exclude-standard @pathspec 2>$null
        foreach ($u in ($untracked | Sort-Object)) {
            $full = Join-Path $Repository $u
            if (Test-Path $full -PathType Leaf) { $null = $sb.AppendLine("${u}:$(Get-SkrContentHash -Path $full)") }
        }
    }
    else {
        $files = Get-SkrRepositoryFile -Repository $Repository -Include '*.cs', '*.razor', '*.cshtml', '*.csproj', '*.props', '*.targets', '*.json', '*.css', '*.js' -ExcludeDirectory @($specsRel)
        foreach ($f in ($files | Sort-Object FullName)) {
            $null = $sb.AppendLine("$(Get-SkrRelativePath -Base $Repository -Path $f.FullName):$(Get-SkrContentHash -Path $f.FullName)")
        }
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [System.Convert]::ToHexString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-SkrMarkdownSection {
    <# Returns the body of a markdown section (any heading level) by title, up to the next heading of the same or higher level. #>
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Markdown, [Parameter(Mandatory)][string] $Title)
    $lines = $Markdown -split "`r?`n"
    $inFence = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*```') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($lines[$i] -match '^(#{1,6})\s+(.+?)\s*$' -and $Matches[2].Trim() -ieq $Title) {
            $level = $Matches[1].Length
            $body = [System.Collections.Generic.List[string]]::new()
            $fence = $false
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^\s*```') { $fence = -not $fence }
                if (-not $fence -and $lines[$j] -match '^(#{1,6})\s+' -and $Matches[1].Length -le $level) { break }
                $body.Add($lines[$j])
            }
            return ($body -join "`n")
        }
    }
    return $null
}

function Get-SkrMarkdownHeading {
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Markdown)
    $inFence = $false
    foreach ($line in ($Markdown -split "`r?`n")) {
        if ($line -match '^\s*```') { $inFence = -not $inFence; continue }
        if (-not $inFence -and $line -match '^#{1,6}\s+(.+?)\s*$') { $Matches[1].Trim() }
    }
}

function Get-SkrMarkdownTableRow {
    <# Parses the first markdown table in a block of text into hashtables keyed by header. #>
    param([AllowEmptyString()][AllowNull()][string] $Markdown)
    if (-not $Markdown) { return @() }
    $rows = [System.Collections.Generic.List[object]]::new()
    $headers = $null
    foreach ($line in ($Markdown -split "`r?`n")) {
        if ($line -notmatch '^\s*\|') { if ($headers) { break } else { continue } }
        $cells = @(($line.Trim().Trim('|') -split '(?<!\\)\|') | ForEach-Object { $_.Trim() })
        if (-not $headers) { $headers = $cells; continue }
        if ($cells[0] -match '^:?-{3,}') { continue }
        $row = [ordered]@{}
        for ($k = 0; $k -lt $headers.Count; $k++) { $row[$headers[$k]] = if ($k -lt $cells.Count) { $cells[$k] } else { '' } }
        $rows.Add($row)
    }
    return $rows.ToArray()
}

function Remove-SkrHtmlComment {
    [OutputType([string])]
    param([AllowEmptyString()][string] $Text)
    return ([regex]::Replace($Text, '<!--.*?-->', '', 'Singleline'))
}
