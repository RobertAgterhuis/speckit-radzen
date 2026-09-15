# Quality gate internals.

function Invoke-SkrProcess {
    <# Runs a process with a timeout and captures combined output. #>
    param(
        [Parameter(Mandatory)][string] $FilePath,
        [Parameter(Mandatory)][string[]] $ArgumentList,
        [Parameter(Mandatory)][string] $WorkingDirectory,
        [int] $TimeoutSeconds = 1200
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new($FilePath)
    foreach ($a in $ArgumentList) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.Environment['DOTNET_CLI_TELEMETRY_OPTOUT'] = '1'
    $psi.Environment['DOTNET_NOLOGO'] = '1'
    $psi.Environment['DOTNET_SKIP_FIRST_TIME_EXPERIENCE'] = '1'
    $psi.Environment['MSBUILDTERMINALLOGGER'] = 'off'
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $out = [System.Text.StringBuilder]::new()
    $handler = { param($s, $e) if ($null -ne $e.Data) { [void]$Event.MessageData.AppendLine($e.Data) } }
    $o = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $handler -MessageData $out
    $r = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action $handler -MessageData $out
    try {
        $null = $proc.Start()
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()
        $timedOut = -not $proc.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut) { try { $proc.Kill($true) } catch { Write-Verbose "Kill failed: $_" } }
        else { $proc.WaitForExit() }
        Start-Sleep -Milliseconds 100
        [pscustomobject]@{ ExitCode = if ($timedOut) { -1 } else { $proc.ExitCode }; Output = $out.ToString(); TimedOut = $timedOut }
    }
    finally {
        Unregister-Event -SourceIdentifier $o.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $r.Name -ErrorAction SilentlyContinue
        $proc.Dispose()
    }
}

function Get-SkrBuildTarget {
    <# Returns the solution/project to build, or throws when it cannot be determined. #>
    param([Parameter(Mandatory)][string] $Repository)
    $prof = Read-SkrJson -Path (Join-Path (Get-SkrStateRoot $Repository) 'profile.json')
    if (-not $prof) { throw "No project profile. Run 'speckit-radzen detect'." }
    if ($prof.repository.solution) { return (Join-Path $Repository $prof.repository.solution) }
    if ($prof.repository.solutionSelection -eq 'ambiguous') { throw "Multiple solutions; run 'speckit-radzen detect -Solution <path>'." }
    $projects = @($prof.projects)
    if ($projects.Count -eq 1) { return (Join-Path $Repository $projects[0].path) }
    throw 'No solution file and not exactly one project; cannot determine what to build.'
}

function ConvertFrom-SkrBuildOutput {
    <# Extracts unique warnings and errors from MSBuild console output. Keys ignore line/column so moved code does not create "new" warnings. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Output, [Parameter(Mandatory)][string] $Repository)
    $warnings = @{}; $errors = @{}
    $rx = '^\s*(?<file>[^\r\n]*?)(?:\((?<line>\d+)(?:,\d+)*\))?\s*:\s*(?<kind>warning|error)\s+(?<code>[A-Za-z]+\d+)\s*:\s*(?<msg>.*?)(?:\s+\[(?<proj>[^\]]+)\])?\s*$'
    foreach ($line in ($Output -split "`r?`n")) {
        $m = [regex]::Match($line, $rx)
        if (-not $m.Success) { continue }
        $file = $m.Groups['file'].Value.Trim()
        if ($file -and [System.IO.Path]::IsPathRooted($file)) {
            try { $file = Get-SkrRelativePath -Base $Repository -Path $file } catch { Write-Verbose "Relative path failed: $_" }
        }
        $file = $file -replace '\\', '/'
        $entry = [ordered]@{ file = $file; line = if ($m.Groups['line'].Success) { [int]$m.Groups['line'].Value } else { 0 }; code = $m.Groups['code'].Value; message = $m.Groups['msg'].Value.Trim() }
        $key = "$($entry.file)|$($entry.code)|$($entry.message)"
        if ($m.Groups['kind'].Value -eq 'warning') { $warnings[$key] = $entry } else { $errors[$key] = $entry }
    }
    [pscustomobject]@{ Warnings = $warnings; Errors = $errors }
}

function Read-SkrTrxResult {
    <# Parses TRX files: totals and failed test names. #>
    param([Parameter(Mandatory)][string] $Directory)
    $total = 0; $passed = 0; $failed = 0; $skipped = 0
    $failedTests = [System.Collections.Generic.List[string]]::new()
    foreach ($trx in (Get-ChildItem -Path $Directory -Filter '*.trx' -Recurse -ErrorAction Ignore)) {
        $xml = Get-SkrXml -Path $trx.FullName
        if (-not $xml) { continue }
        $counters = $xml.SelectSingleNode('//*[local-name()="Counters"]')
        if ($counters) {
            $total += [int]$counters.GetAttribute('total')
            $passed += [int]$counters.GetAttribute('passed')
            $failed += [int]$counters.GetAttribute('failed') + [int]($counters.GetAttribute('error') -as [int])
            $skipped += [int]($counters.GetAttribute('notExecuted') -as [int])
        }
        foreach ($r in $xml.SelectNodes('//*[local-name()="UnitTestResult"][@outcome="Failed"]')) { $failedTests.Add($r.GetAttribute('testName')) }
    }
    [pscustomobject]@{ Total = $total; Passed = $passed; Failed = $failed; Skipped = $skipped; FailedTests = @($failedTests | Select-Object -Unique) }
}

function Invoke-SkrBuildAndTest {
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][hashtable] $G5Config, [switch] $SkipTests)
    if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'dotnet SDK not found on PATH.' }
    $target = Get-SkrBuildTarget -Repository $Repository
    $timeout = [int]$G5Config.timeoutMinutes * 60
    $cfg = if ($G5Config.buildConfiguration) { $G5Config.buildConfiguration } else { 'Debug' }
    $build = Invoke-SkrProcess -FilePath 'dotnet' -ArgumentList @('build', $target, '--no-incremental', '-c', $cfg, '-nologo', '-v:q', '-clp:NoSummary') -WorkingDirectory $Repository -TimeoutSeconds $timeout
    $parsed = ConvertFrom-SkrBuildOutput -Output $build.Output -Repository $Repository
    $result = [ordered]@{
        target = Get-SkrRelativePath -Base $Repository -Path $target
        buildExitCode = $build.ExitCode; buildTimedOut = $build.TimedOut
        warnings = @($parsed.Warnings.Values); errors = @($parsed.Errors.Values)
        tests = $null; testExitCode = $null; buildOutputTail = (($build.Output -split "`r?`n") | Select-Object -Last 40) -join "`n"
    }
    if ($build.ExitCode -eq 0 -and -not $SkipTests -and $G5Config.runTests) {
        $resultsDir = Join-Path (Get-SkrStateRoot $Repository) 'tmp' ('test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $testArgs = @('test', $target, '--no-build', '-c', $cfg, '--logger', 'trx', '--results-directory', $resultsDir, '-nologo')
        if ($G5Config.testFilter) { $testArgs += @('--filter', $G5Config.testFilter) }
        $test = Invoke-SkrProcess -FilePath 'dotnet' -ArgumentList $testArgs -WorkingDirectory $Repository -TimeoutSeconds $timeout
        $result.testExitCode = $test.ExitCode
        $result.tests = Read-SkrTrxResult -Directory $resultsDir
        $result.testOutputTail = (($test.Output -split "`r?`n") | Select-Object -Last 30) -join "`n"
        Remove-Item -Path $resultsDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    return [pscustomobject]$result
}

function Get-SkrDependencySnapshot {
    param([Parameter(Mandatory)][string] $Repository)
    $prof = Get-SkrProjectProfile -Repository $Repository -NoWrite
    $map = [ordered]@{}
    foreach ($p in ($prof.projects | Sort-Object path)) {
        foreach ($prop in $p.packages.PSObject.Properties) { $map["$($p.path)|$($prop.Name)"] = $prop.Value }
    }
    [ordered]@{
        capturedAt = Get-SkrTimestamp
        projects   = @($prof.projects | ForEach-Object { $_.path } | Sort-Object)
        packages   = $map
    }
}

function Write-SkrGateReport {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $state = Get-SkrState -FeaturePath $FeaturePath
    $defs = (Read-SkrJson -Path (Join-Path (Get-SkrCoreRoot) 'gates' 'gates.json')).gates
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Gate Report: $($state.feature)")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine("- **Phase:** $($state.phase)")
    $null = $sb.AppendLine("- **MCP availability:** $($state.mcp.availability)")
    $null = $sb.AppendLine("- **Updated:** $(Get-SkrTimestamp)")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('Generated by `speckit-radzen gate`. Details per gate in `gates/G#.json`.')
    $null = $sb.AppendLine()
    $rows = foreach ($d in $defs) {
        $g = $state.gates[$d.id]
        [pscustomobject]@{ Gate = $d.id; Name = $d.name; Status = if ($g) { $g.status.ToUpperInvariant() } else { 'not run' }; When = if ($g) { $g.at } else { '' }; Slice = if ($g -and $g.slice) { $g.slice } else { '' } }
    }
    $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($rows) -Columns 'Gate', 'Name', 'Status', 'When', 'Slice'))
    if ($state.slices.Count) {
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('## Slices')
        $null = $sb.AppendLine()
        $srows = foreach ($k in ($state.slices.Keys | Sort-Object)) { [pscustomobject]@{ Slice = $k; Status = $state.slices[$k].status; G5 = $state.slices[$k].g5; G6 = $state.slices[$k].g6 } }
        $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($srows) -Columns 'Slice', 'Status', 'G5', 'G6'))
    }
    foreach ($d in $defs) {
        $file = Join-Path $FeaturePath 'gates' "$($d.id).json"
        if (-not (Test-Path $file)) { continue }
        $res = Read-SkrJson -Path $file
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("## $($d.id) — $($d.name): $($res.status.ToUpperInvariant())")
        $null = $sb.AppendLine()
        $crow = foreach ($c in $res.checks) { [pscustomobject]@{ Check = $c.check; Status = $c.status; Message = $c.message } }
        $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows @($crow) -Columns 'Check', 'Status', 'Message'))
    }
    Write-SkrText -Path (Join-Path $FeaturePath 'gate-report.md') -Content $sb.ToString()
}
