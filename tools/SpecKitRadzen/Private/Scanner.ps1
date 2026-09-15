# Anti-pattern scanner internals.

$script:SkrWaiverPattern = 'speckit-radzen:ignore(?<file>-file)?\s+(?<ids>AP-[A-Z0-9]+-\d{2}(?:\s*,\s*AP-[A-Z0-9]+-\d{2})*)(?:\s+reason\s*=\s*"(?<reason>[^"]*)")?'

function Get-SkrAntiPatternRule {
    param([Parameter(Mandatory)][string] $Repository, [hashtable] $Config)
    $rules = [System.Collections.Generic.List[object]]::new()
    foreach ($r in (Read-SkrJson -Path (Join-Path (Get-SkrCoreRoot) 'antipatterns' 'rules.json')).rules) { $rules.Add($r) }
    $localPath = Join-Path (Get-SkrStateRoot $Repository) 'local' 'antipatterns.local.json'
    if (Test-Path $localPath) {
        $local = Read-SkrJson -Path $localPath
        $errors = Test-SkrJsonSchema -Json (Get-Content $localPath -Raw) -SchemaName 'antipattern-rules'
        if ($errors.Count) { throw "Invalid $localPath : $($errors -join '; ')" }
        foreach ($r in $local.rules) {
            $existing = $rules | Where-Object id -eq $r.id
            if ($existing) { $null = $rules.Remove(@($existing)[0]) }
            $rules.Add($r)
        }
    }
    $disabled = @($Config.scan.disabledRules)
    $overrides = $Config.scan.severityOverrides
    foreach ($r in $rules) {
        if ($disabled -contains $r.id) { continue }
        if ($overrides -and $overrides.ContainsKey($r.id)) { $r = $r.PSObject.Copy(); $r.severity = $overrides[$r.id] }
        $r
    }
}

function Test-SkrGlob {
    <# Glob match for repository-relative paths: ** = any depth, * = within a segment. Patterns without '/' match the file name. #>
    [OutputType([bool])]
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Pattern)
    if ($Pattern -notmatch '/') { return ([System.IO.Path]::GetFileName($Path) -like $Pattern) }
    $rx = '^' + ([regex]::Escape($Pattern) -replace '\\\*\\\*/', '(.*/)?' -replace '\\\*\\\*', '.*' -replace '\\\*', '[^/]*' -replace '\\\?', '[^/]') + '$'
    return ($Path -match $rx)
}

function Test-SkrTestPath {
    [OutputType([bool])]
    param([Parameter(Mandatory)][string] $RelativePath)
    return ($RelativePath -match '(?i)(^|/)(tests?|specs?\.tests?|[^/]*\.(unit|integration|component|e2e)?tests?)/' -or $RelativePath -match '(?i)tests?\.cs$')
}

function Get-SkrWaiver {
    <# Returns waivers that apply to a line (same line or the line above) and file-level waivers. #>
    param([string[]] $Lines, [int] $LineNumber, [string[]] $FileWaiverLines)
    $result = @()
    $candidates = @()
    if ($LineNumber -ge 1 -and $LineNumber -le $Lines.Count) { $candidates += $Lines[$LineNumber - 1] }
    if ($LineNumber -ge 2) { $candidates += $Lines[$LineNumber - 2] }
    foreach ($text in @($candidates) + @($FileWaiverLines)) {
        foreach ($m in [regex]::Matches($text, $script:SkrWaiverPattern)) {
            $isFile = $m.Groups['file'].Success
            if ($isFile -and $FileWaiverLines -notcontains $text) { continue }
            foreach ($id in ($m.Groups['ids'].Value -split '\s*,\s*')) {
                $result += [pscustomobject]@{ Id = $id; Reason = $m.Groups['reason'].Value; HasReason = $m.Groups['reason'].Success -and $m.Groups['reason'].Value.Trim().Length -ge 3 }
            }
        }
    }
    return $result
}

function New-SkrFinding {
    param($Rule, [string] $File, [int] $Line, [string] $Snippet, [string] $Message, [string] $WaiverReason, [bool] $Waived)
    [pscustomobject]@{
        rule     = $Rule.id
        title    = $Rule.title
        severity = $Rule.severity
        file     = $File
        line     = $Line
        message  = if ($Message) { $Message } elseif ($Rule.PSObject.Properties['message'] -and $Rule.message) { $Rule.message } else { $Rule.title }
        snippet  = if ($Snippet) { ($Snippet.Trim() -replace '\s+', ' ').Substring(0, [Math]::Min(160, ($Snippet.Trim() -replace '\s+', ' ').Length)) } else { '' }
        waived   = $Waived
        waiver   = $WaiverReason
        fix      = $Rule.fix
        doc      = "core/antipatterns/$($Rule.doc)"
    }
}

function ConvertTo-SkrSarif {
    param([Parameter(Mandatory)] $Result, [Parameter(Mandatory)] $Rules)
    $level = @{ blocker = 'error'; major = 'error'; minor = 'warning' }
    $usedIds = @($Result.findings | ForEach-Object rule | Select-Object -Unique)
    $sarifRules = @($Rules | Where-Object { $usedIds -contains $_.id } | ForEach-Object {
            [ordered]@{
                id = $_.id; name = ($_.title -replace '[^A-Za-z0-9]', '')
                shortDescription = @{ text = $_.title }
                fullDescription = @{ text = $_.why }
                help = @{ text = $_.fix }
                properties = @{ severity = $_.severity; category = $_.category; principles = @($_.principles) }
            }
        })
    $results = @($Result.findings | ForEach-Object {
            $r = [ordered]@{
                ruleId = $_.rule; level = $level[$_.severity]; message = @{ text = $_.message }
                locations = @(@{ physicalLocation = @{ artifactLocation = @{ uri = $_.file }; region = @{ startLine = [Math]::Max(1, $_.line) } } })
            }
            if ($_.waived) { $r.suppressions = @(@{ kind = 'inSource'; justification = $_.waiver }) }
            $r
        })
    [ordered]@{
        '$schema' = 'https://json.schemastore.org/sarif-2.1.0.json'
        version   = '2.1.0'
        runs      = @(@{
                tool    = @{ driver = @{ name = 'speckit-radzen'; version = (Get-SkrKitVersion); informationUri = 'https://github.com/'; rules = $sarifRules } }
                results = $results
            })
    }
}

function ConvertTo-SkrScanMarkdown {
    param([Parameter(Mandatory)] $Result)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('# Anti-pattern scan')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("- **Scanned:** $($Result.scannedFiles) file(s) ($($Result.scope))")
    $null = $sb.AppendLine("- **Findings:** blocker $($Result.summary.blocker) · major $($Result.summary.major) · minor $($Result.summary.minor) · waived $($Result.summary.waived)")
    $null = $sb.AppendLine("- **Generated:** $($Result.generatedAt)")
    $null = $sb.AppendLine()
    $active = @($Result.findings | Where-Object { -not $_.waived })
    if ($active.Count) {
        $null = $sb.AppendLine('## Findings')
        $null = $sb.AppendLine()
        $rows = $active | Sort-Object @{ e = { @{ blocker = 0; major = 1; minor = 2 }[$_.severity] } }, file, line | ForEach-Object {
            [pscustomobject]@{ Severity = $_.severity; Rule = $_.rule; Location = "$($_.file):$($_.line)"; Message = $_.message; Fix = $_.fix }
        }
        $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($rows) -Columns 'Severity', 'Rule', 'Location', 'Message', 'Fix'))
        $null = $sb.AppendLine()
    }
    else { $null = $sb.AppendLine('No active findings.'); $null = $sb.AppendLine() }
    $waived = @($Result.findings | Where-Object waived)
    if ($waived.Count) {
        $null = $sb.AppendLine('## Waived')
        $null = $sb.AppendLine()
        $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($waived | ForEach-Object { [pscustomobject]@{ Rule = $_.rule; Location = "$($_.file):$($_.line)"; Reason = $_.waiver } }) -Columns 'Rule', 'Location', 'Reason'))
        $null = $sb.AppendLine()
    }
    $null = $sb.AppendLine('## Manual review required (G7)')
    $null = $sb.AppendLine()
    $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($Result.manual) -Columns 'id', 'severity', 'title'))
    return $sb.ToString()
}
