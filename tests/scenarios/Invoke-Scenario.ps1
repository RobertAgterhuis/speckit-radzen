#Requires -Version 7.4
<#
.SYNOPSIS
    Prepares, runs (optionally headless) and evaluates an agent-behaviour scenario.
.PARAMETER Id
    Scenario ID, e.g. SC-01.
.PARAMETER Agent
    Adapter to install in the sandbox: claude, copilot, codex, cursor, generic.
.PARAMETER Headless
    Run Claude Code non-interactively (`claude -p`) in the sandbox and save TRANSCRIPT.md.
.PARAMETER Evaluate
    Run the automated checks against -Sandbox and write a result file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^SC-\d{2}$')][string] $Id,
    [ValidateSet('claude', 'copilot', 'codex', 'cursor', 'generic')][string] $Agent = 'claude',
    [switch] $Headless,
    [switch] $Evaluate,
    [string] $Sandbox,
    [ValidateRange(0, 10)][int] $Score = -1,
    [string] $Reviewer,
    [string] $Notes
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
Import-Module (Join-Path $root 'tools' 'SpecKitRadzen' 'SpecKitRadzen.psd1') -Force
$file = Join-Path $PSScriptRoot "$Id.md"
$text = Get-Content $file -Raw
$harness = [regex]::Match($text, '(?s)## Harness\s*```json\s*(.*?)```').Groups[1].Value | ConvertFrom-Json -AsHashtable
$prompt = [regex]::Match($text, '(?s)## Prompt\s*```text\s*(.*?)```').Groups[1].Value.Trim()

function Get-PackageMap([string] $repo) {
    $map = @{}
    foreach ($p in (Get-SkrProjectProfile -Repository $repo -NoWrite).projects) {
        foreach ($prop in $p.packages.PSObject.Properties) { $map["$($p.path)|$($prop.Name)"] = "$($prop.Value)" }
    }
    return $map
}

if (-not $Evaluate) {
    $Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("skr-scn-$($Id.ToLowerInvariant())-" + (Get-Date -Format 'yyyyMMddHHmmss'))
    Copy-Item (Join-Path $root 'tests' 'fixtures' 'repos' $harness.fixture) $Sandbox -Recurse
    foreach ($step in $harness.setup) {
        if ($step.write) { $p = Join-Path $Sandbox $step.write.path; New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; Set-Content -Path $p -Value $step.write.content -NoNewline }
        if ($step.remove) { Remove-Item (Join-Path $Sandbox $step.remove) -Recurse -Force -ErrorAction SilentlyContinue }
        if ($step.env) { foreach ($k in $step.env.Keys) { [Environment]::SetEnvironmentVariable($k, $step.env[$k]) } }
    }
    Set-Content (Join-Path $Sandbox '.gitignore') "bin/`nobj/`n.scenario/"
    & git -C $Sandbox init -q -b main; & git -C $Sandbox add -A
    & git -C $Sandbox -c user.email=scenario@example.invalid -c user.name=scenario commit -q -m 'scenario fixture'
    $null = Install-SpecKitRadzen -Repository $Sandbox -Agents $Agent -Source $root -Yes
    & git -C $Sandbox add -A; & git -C $Sandbox -c user.email=scenario@example.invalid -c user.name=scenario commit -q -m 'install spec kit radzen'
    $meta = Join-Path $Sandbox '.scenario'
    New-Item -ItemType Directory $meta | Out-Null
    $harness | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $meta 'harness.json')
    Get-PackageMap $Sandbox | ConvertTo-Json | Set-Content (Join-Path $meta 'packages.json')
    Set-Content (Join-Path $meta 'PROMPT.md') $prompt
    Write-Host "Sandbox: $Sandbox"
    Write-Host "Prompt:`n$prompt"
    if ($Headless) {
        if ($Agent -ne 'claude' -or -not (Get-Command claude -ErrorAction Ignore)) { throw 'Headless mode requires the claude CLI and -Agent claude.' }
        Push-Location $Sandbox
        try { $out = & claude -p $prompt --output-format text 2>&1 }
        finally { Pop-Location }
        Set-Content (Join-Path $Sandbox 'TRANSCRIPT.md') ($out -join "`n")
        Write-Host 'Transcript saved. Evaluate with:'
    }
    else { Write-Host 'Run the prompt in your agent, save the conversation as TRANSCRIPT.md in the sandbox, then evaluate with:' }
    Write-Host "  ./tests/scenarios/Invoke-Scenario.ps1 -Id $Id -Agent $Agent -Evaluate -Sandbox '$Sandbox' -Score <0-10> -Reviewer <name>"
    return
}

if (-not $Sandbox -or -not (Test-Path $Sandbox)) { throw '-Sandbox is required with -Evaluate.' }
$transcriptPath = Join-Path $Sandbox 'TRANSCRIPT.md'
$transcript = if (Test-Path $transcriptPath) { Get-Content $transcriptPath -Raw } else { '' }
$feature = Get-ChildItem (Join-Path $Sandbox 'specs') -Directory -ErrorAction Ignore | Sort-Object Name | Select-Object -Last 1
$scan = $null
$results = [System.Collections.Generic.List[object]]::new()
$record = { param($check, $ok, $detail) $results.Add([pscustomobject]@{ Check = $check; Result = if ($ok) { 'pass' } else { 'FAIL' }; Detail = $detail }) }
$glob = { param($pattern) @(Get-ChildItem -Path (Join-Path $Sandbox $pattern) -File -ErrorAction Ignore) }

foreach ($c in $harness.checks) {
    $label = "$($c.type) $((@($c.Keys | Where-Object { $_ -ne 'type' } | ForEach-Object { "$_=$($c[$_])" })) -join ' ')"
    switch ($c.type) {
        'scanAbsent' {
            if (-not $scan) { $scan = Invoke-SkrAntiPatternScan -Repository $Sandbox -All -NoWrite }
            $hits = @($scan.findings | Where-Object { $_.rule -eq $c.rule -and -not $_.waived })
            & $record $label (-not $hits.Count) (($hits | ForEach-Object { "$($_.file):$($_.line)" }) -join ', ')
        }
        'evidenceComponent' {
            $ok = $false
            if ($feature -and (Test-Path (Join-Path $feature.FullName 'mcp-evidence.json'))) {
                $ok = [bool]@((Get-Content (Join-Path $feature.FullName 'mcp-evidence.json') -Raw | ConvertFrom-Json).entries | Where-Object { $_.component -match $c.name }).Count
            }
            & $record $label $ok ''
        }
        'evidenceMaxRank' {
            $entries = @(if ($feature) { (Get-Content (Join-Path $feature.FullName 'mcp-evidence.json') -Raw | ConvertFrom-Json).entries | Where-Object status -ne 'superseded' })
            $bad = @($entries | Where-Object { $_.rank -gt $c.max -or ($_.rank -eq 4 -and -not $_.fallbackApproved) })
            & $record $label (-not $bad.Count) (($bad | ForEach-Object id) -join ', ')
        }
        'fileContains' {
            $files = & $glob $c.path
            $ok = [bool]@($files | Where-Object { (Get-Content $_.FullName -Raw) -match $c.pattern }).Count
            & $record $label $ok "$($files.Count) file(s) matched the path"
        }
        'fileExists' { & $record $label (Test-Path (Join-Path $Sandbox $c.path)) '' }
        'gateStatus' {
            $g = if ($feature) { Join-Path $feature.FullName "gates/$($c.gate).json" }
            $status = if ($g -and (Test-Path $g)) { (Get-Content $g -Raw | ConvertFrom-Json).status } else { 'not run' }
            & $record $label (@($c.status) -contains $status) $status
        }
        'stateMcp' {
            $status = if ($feature) { (Get-Content (Join-Path $feature.FullName 'state.json') -Raw | ConvertFrom-Json).mcp.availability } else { 'no feature' }
            & $record $label (@($c.value) -contains $status) $status
        }
        'outputContains' { & $record $label ($transcript -match $c.pattern) $(if (-not $transcript) { 'no TRANSCRIPT.md' }) }
        'outputNotContains' { & $record $label ($transcript -and $transcript -notmatch $c.pattern) $(if (-not $transcript) { 'no TRANSCRIPT.md' }) }
        'repoNotContains' {
            $hits = @(Get-ChildItem $Sandbox -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/](\.git|\.scenario)[\\/]' -and $_.Name -ne 'TRANSCRIPT.md' -and $_.Length -lt 2MB } | Where-Object { (Get-Content $_.FullName -Raw) -match $c.pattern })
            & $record $label (-not $hits.Count) (($hits | ForEach-Object Name) -join ', ')
        }
        'mcpStatusNot' { $s = (Test-SkrMcpConfiguration -Repository $Sandbox -SkipUserLevel).Status; & $record $label ($s -ne $c.value) $s }
        'packageUnchanged' {
            $before = Get-Content (Join-Path $Sandbox '.scenario/packages.json') -Raw | ConvertFrom-Json -AsHashtable
            $after = Get-PackageMap $Sandbox
            $changed = @($after.Keys | Where-Object { $_ -like "*|$($c.package)" -and $before[$_] -ne $after[$_] })
            & $record $label (-not $changed.Count) ($changed -join ', ')
        }
        'packageAbsentUnlessApproved' {
            $before = Get-Content (Join-Path $Sandbox '.scenario/packages.json') -Raw | ConvertFrom-Json -AsHashtable
            $after = Get-PackageMap $Sandbox
            $added = @($after.Keys | Where-Object { $_ -like "*|$($c.package)*" -and -not $before.ContainsKey($_) })
            $approved = $feature -and (Test-Path (Join-Path $feature.FullName 'plan.md')) -and ((Get-Content (Join-Path $feature.FullName 'plan.md') -Raw) -match "(?s)## Approved dependency changes.*$([regex]::Escape($c.package))")
            & $record $label ((-not $added.Count) -or $approved) ($added -join ', ')
        }
        'outputMatchesGateFiles' {
            $claims = @([regex]::Matches($transcript, '\b(G[0-8])\b[^\n]{0,40}\bPASS') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
            $bad = @($claims | Where-Object { -not $feature -or -not (Test-Path (Join-Path $feature.FullName "gates/$_.json")) -or (Get-Content (Join-Path $feature.FullName "gates/$_.json") -Raw | ConvertFrom-Json).status -notin 'pass', 'waived' })
            & $record $label (-not $bad.Count) "claims: $($claims -join ', '); unsupported: $($bad -join ', ')"
        }
        default { & $record $label $false 'unknown check type' }
    }
}

$passed = @($results | Where-Object Result -eq 'pass').Count
$resultFile = Join-Path $PSScriptRoot 'results' ("{0}-{1}-{2}.md" -f (Get-Date -Format 'yyyy-MM-dd'), $Id, $Agent)
$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine("# $Id result ($Agent)")
$null = $sb.AppendLine()
$null = $sb.AppendLine("- **Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
$null = $sb.AppendLine("- **Kit:** $((Get-Content (Join-Path $root 'VERSION') -Raw).Trim())")
$null = $sb.AppendLine("- **Automated checks:** $passed/$($results.Count) passed")
$null = $sb.AppendLine("- **Rubric score:** $(if ($Score -ge 0) { "$Score/10" } else { 'not scored' })$(if ($Reviewer) { " (by $Reviewer)" })")
$null = $sb.AppendLine("- **Transcript:** $(if ($transcript) { 'present' } else { 'missing' })")
if ($Notes) { $null = $sb.AppendLine("- **Notes:** $Notes") }
$null = $sb.AppendLine()
$null = $sb.AppendLine('| Check | Result | Detail |')
$null = $sb.AppendLine('|---|---|---|')
foreach ($r in $results) { $null = $sb.AppendLine("| $($r.Check -replace '\|', '\|') | $($r.Result) | $($r.Detail -replace '\|', '\|') |") }
Set-Content -Path $resultFile -Value $sb.ToString()
$results | Format-Table -AutoSize | Out-String -Width 200
Write-Host "Result: $resultFile"
if ($passed -ne $results.Count) { exit 1 }
