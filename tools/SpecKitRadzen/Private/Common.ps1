# Shared helpers. Prefix: Skr (Spec Kit Radzen). Not exported.

$script:SkrExcludedDirectories = @('.git', 'bin', 'obj', 'node_modules', '.vs', '.idea', 'TestResults', 'packages', 'artifacts', '.speckit')
$script:SkrUtf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Get-SkrKitRoot {
    <# Returns the folder that contains core/ and tools/ (the distribution root or .speckit/radzen in a target repo). #>
    [OutputType([string])]
    param()
    return (Resolve-Path (Join-Path $script:ModuleRoot '..' '..')).Path
}

function Get-SkrCoreRoot {
    [OutputType([string])]
    param()
    $core = Join-Path (Get-SkrKitRoot) 'core'
    if (-not (Test-Path $core)) { throw "Spec Kit Radzen core not found at '$core'." }
    return $core
}

function Get-SkrKitVersion {
    [OutputType([string])]
    param()
    $root = Get-SkrKitRoot
    foreach ($candidate in @((Join-Path $root 'VERSION'), (Join-Path $root 'core' 'VERSION'))) {
        if (Test-Path $candidate) { return (Get-Content $candidate -Raw).Trim() }
    }
    return (Import-PowerShellDataFile (Join-Path $script:ModuleRoot 'SpecKitRadzen.psd1')).ModuleVersion
}

function Resolve-SkrRepository {
    <# Resolves the target repository root: the nearest directory (the given one or an ancestor) that contains .git, .speckit/radzen, a solution file or global.json. Falls back to the given path. #>
    [OutputType([string])]
    param([string] $Path = (Get-Location).Path)
    if (-not (Test-Path $Path -PathType Container)) { throw "Repository path '$Path' does not exist or is not a directory." }
    $full = (Resolve-Path $Path).Path
    $probe = $full
    while ($probe) {
        if (Test-Path (Join-Path $probe '.git')) { return $probe }
        if (Test-Path (Join-Path $probe '.speckit' 'radzen')) { return $probe }
        if (Get-ChildItem -Path $probe -File -Include '*.sln', '*.slnx', 'global.json' -Name -ErrorAction Ignore | Select-Object -First 1) { return $probe }
        $parent = Split-Path $probe -Parent
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
    return $full
}

function Get-SkrStateRoot {
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Repository)
    return (Join-Path $Repository '.speckit' 'radzen')
}

function Read-SkrJson {
    param([Parameter(Mandatory)][string] $Path, [switch] $AsHashtable)
    if (-not (Test-Path $Path)) { return $null }
    $raw = Get-Content -Path $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    if ($AsHashtable) { return ($raw | ConvertFrom-Json -AsHashtable -Depth 64 -DateKind String) }
    return ($raw | ConvertFrom-Json -Depth 64 -DateKind String)
}

function Write-SkrText {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][AllowEmptyString()][string] $Content)
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    $normalized = ($Content -replace "`r`n", "`n")
    if (-not $normalized.EndsWith("`n")) { $normalized += "`n" }
    [System.IO.File]::WriteAllText($Path, $normalized, $script:SkrUtf8NoBom)
}

function Write-SkrJson {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)] $InputObject)
    Write-SkrText -Path $Path -Content ($InputObject | ConvertTo-Json -Depth 64)
}

function Get-SkrContentHash {
    <# SHA-256 of file content with line endings normalized, so git autocrlf does not cause false "modified" results. #>
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $isText = -not ($bytes -contains 0)
    if ($isText) {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes) -replace "`r`n", "`n"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.Convert]::ToHexString($sha.ComputeHash($bytes))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-SkrRelativePath {
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $Base, [Parameter(Mandatory)][string] $Path)
    return ([System.IO.Path]::GetRelativePath($Base, $Path) -replace '\\', '/')
}

function Get-SkrRepositoryFile {
    <# Enumerates repository files matching the given name patterns, skipping build output, VCS and kit folders. #>
    param(
        [Parameter(Mandatory)][string] $Repository,
        [string[]] $Include = @('*'),
        [string[]] $ExcludeDirectory = @()
    )
    $excluded = @($script:SkrExcludedDirectories + $ExcludeDirectory)
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($Repository)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        foreach ($child in [System.IO.Directory]::EnumerateDirectories($dir)) {
            $name = [System.IO.Path]::GetFileName($child)
            if ($excluded -contains $name) { continue }
            $rel = Get-SkrRelativePath -Base $Repository -Path $child
            if ($excluded | Where-Object { $_.Contains('/') -and ($rel -eq $_ -or $rel.StartsWith("$_/")) }) { continue }
            $stack.Push($child)
        }
        foreach ($file in [System.IO.Directory]::EnumerateFiles($dir)) {
            $fileName = [System.IO.Path]::GetFileName($file)
            foreach ($pattern in $Include) {
                if ($fileName -like $pattern) { [System.IO.FileInfo]::new($file); break }
            }
        }
    }
}

function Get-SkrGitChangedFile {
    <# Returns repository-relative paths changed against a base ref (committed, staged, unstaged and untracked). Returns $null when git is unavailable. #>
    param([Parameter(Mandatory)][string] $Repository, [string] $Base = 'HEAD')
    if (-not (Get-Command git -ErrorAction Ignore)) { return $null }
    if (-not (Test-Path (Join-Path $Repository '.git'))) { return $null }
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $commands = @(
        @('diff', '--name-only', '--diff-filter=ACMR', $Base),
        @('diff', '--name-only', '--diff-filter=ACMR', '--cached'),
        @('ls-files', '--others', '--exclude-standard')
    )
    foreach ($arguments in $commands) {
        $out = & git -C $Repository @arguments 2>$null
        if ($LASTEXITCODE -ne 0) { continue }
        foreach ($line in $out) { if ($line) { $null = $files.Add(($line -replace '\\', '/')) } }
    }
    return @($files)
}

function Get-SkrLineNumber {
    <# Converts a character index into a 1-based line number. #>
    [OutputType([int])]
    param([Parameter(Mandatory)][string] $Text, [Parameter(Mandatory)][int] $Index)
    if ($Index -le 0) { return 1 }
    return ([regex]::Matches($Text.Substring(0, [Math]::Min($Index, $Text.Length)), "`n").Count + 1)
}

function ConvertTo-SkrMarkdownTable {
    [OutputType([string])]
    param([Parameter(Mandatory)][object[]] $Rows, [Parameter(Mandatory)][string[]] $Columns)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('| ' + ($Columns -join ' | ') + ' |')
    $null = $sb.AppendLine('|' + (($Columns | ForEach-Object { '---' }) -join '|') + '|')
    foreach ($row in $Rows) {
        $cells = foreach ($c in $Columns) {
            $v = if ($row -is [System.Collections.IDictionary]) { $row[$c] } else { $row.$c }
            if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { $v = ($v -join ', ') }
            ("$v" -replace '\|', '\|' -replace "`r?`n", ' ')
        }
        $null = $sb.AppendLine('| ' + ($cells -join ' | ') + ' |')
    }
    return $sb.ToString()
}

function Get-SkrTimestamp {
    [OutputType([string])]
    param()
    return [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Get-SkrConfig {
    <# Effective configuration: core defaults merged with the repository's .speckit/radzen/config.json. #>
    param([Parameter(Mandatory)][string] $Repository)
    $defaults = Read-SkrJson -Path (Join-Path (Get-SkrCoreRoot) 'config' 'config.default.json') -AsHashtable
    if (-not $defaults) { $defaults = @{} }
    $local = Read-SkrJson -Path (Join-Path (Get-SkrStateRoot $Repository) 'config.json') -AsHashtable
    if ($local) { $defaults = Merge-SkrHashtable -Base $defaults -Override $local }
    return $defaults
}

function Merge-SkrHashtable {
    param([Parameter(Mandatory)][hashtable] $Base, [Parameter(Mandatory)][hashtable] $Override)
    $result = @{}
    foreach ($k in $Base.Keys) { $result[$k] = $Base[$k] }
    foreach ($k in $Override.Keys) {
        if ($result[$k] -is [hashtable] -and $Override[$k] -is [hashtable]) {
            $result[$k] = Merge-SkrHashtable -Base $result[$k] -Override $Override[$k]
        }
        else { $result[$k] = $Override[$k] }
    }
    return $result
}

function Test-SkrJsonSchema {
    <# Validates JSON text against a schema from core/schemas. Returns an array of error strings (empty when valid). #>
    param([Parameter(Mandatory)][string] $Json, [Parameter(Mandatory)][string] $SchemaName)
    $schemaPath = Join-Path (Get-SkrCoreRoot) 'schemas' "$SchemaName.schema.json"
    if (-not (Test-Path $schemaPath)) { throw "Schema '$SchemaName' not found." }
    $errors = @()
    try {
        $ok = Test-Json -Json $Json -SchemaFile $schemaPath -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
        if (-not $ok) { $errors = @($schemaErrors | ForEach-Object { $_.Exception.Message + ' ' + $_.ErrorDetails.Message }) }
    }
    catch { $errors = @($_.Exception.Message) }
    return , $errors
}

function New-SkrResult {
    <# Standard result object used by gates, scans and lint. #>
    param(
        [Parameter(Mandatory)][ValidateSet('pass', 'fail', 'waived', 'error', 'skipped', 'manual')] [string] $Status,
        [Parameter(Mandatory)][string] $Check,
        [string] $Message = '',
        [object[]] $Evidence = @()
    )
    [pscustomobject]@{ check = $Check; status = $Status; message = $Message; evidence = @($Evidence) }
}
