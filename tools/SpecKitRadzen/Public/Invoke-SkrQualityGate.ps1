function Invoke-SkrQualityGate {
    <#
    .SYNOPSIS
        Runs a quality gate (G0–G8) for a feature, writes gates/G#.json and gate-report.md, and updates state.json.
    .OUTPUTS
        The gate result. ExitCode: 0 pass, 1 fail, 2 pass with waivers, 3 cannot evaluate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][ValidatePattern('^G[0-8]$')][string] $Gate,
        [string] $Feature,
        [ValidatePattern('^S-[0-9]{2}$')][string] $Slice,
        [string] $Repository = (Get-Location).Path
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $f = Resolve-SkrFeature -Repository $repo -Feature $Feature
    $state = Get-SkrState -FeaturePath $f.Path
    $config = Get-SkrConfig -Repository $repo
    $defs = (Read-SkrJson -Path (Join-Path (Get-SkrCoreRoot) 'gates' 'gates.json')).gates
    $def = $defs | Where-Object id -eq $Gate
    $started = Get-SkrTimestamp
    $checks = [System.Collections.Generic.List[object]]::new()
    $add = { param($check, $status, $message, $evidence) $checks.Add((New-SkrResult -Status $status -Check $check -Message $message -Evidence @($evidence))) }
    $stateRoot = Get-SkrStateRoot $repo
    $gatesDir = Join-Path $f.Path 'gates'
    $null = New-Item -ItemType Directory -Force -Path $gatesDir

    $lintCheck = {
        param([string] $name, [string[]] $artifacts)
        $findings = @(Test-SkrArtifact -Feature $f.Id -Artifact $artifacts -Strict -Repository $repo)
        $errs = @($findings | Where-Object severity -eq 'error')
        $warns = @($findings | Where-Object severity -eq 'warning')
        if ($errs.Count) { & $add $name 'fail' "$($errs.Count) error(s)" @($errs | ForEach-Object { "$($_.artifact): $($_.message)" }) }
        else { & $add $name 'pass' "clean$(if ($warns.Count) { " ($($warns.Count) warning(s))" })" @($warns | ForEach-Object { "$($_.artifact): $($_.message)" }) }
    }
    $profileFresh = {
        $pp = Join-Path $stateRoot 'profile.json'
        if (-not (Test-Path $pp)) { & $add 'profile-fresh' 'error' "No profile. Run 'speckit-radzen detect'." @(); return }
        $prof = Read-SkrJson -Path $pp
        $now = Get-SkrProfileFingerprint -Repository $repo
        if ($prof.fingerprint -ne $now) { & $add 'profile-fresh' 'fail' "Profile is stale (project files changed). Run 'speckit-radzen detect'." @() }
        else { & $add 'profile-fresh' 'pass' "fingerprint $($now.Substring(0, 12))" @() }
    }

    try {
        switch ($Gate) {
            'G0' {
                if (Test-Path (Join-Path $stateRoot 'install-manifest.json')) {
                    if (Get-Command Test-SpecKitRadzenInstall -ErrorAction Ignore) {
                        $inst = Test-SpecKitRadzenInstall -Repository $repo
                        if ($inst.Healthy) { & $add 'install-verified' 'pass' "kit $($inst.KitVersion)" @() }
                        else { & $add 'install-verified' 'fail' 'Managed files are missing or modified.' @($inst.Problems) }
                    }
                    else { & $add 'install-verified' 'skipped' 'Installer module not available.' @() }
                }
                else { & $add 'install-verified' 'skipped' 'No install manifest (running from the distribution or a manual copy).' @() }

                $pp = Join-Path $stateRoot 'profile.json'
                if (-not (Test-Path $pp)) { & $add 'profile-present' 'error' "Run 'speckit-radzen detect' first." @() }
                else {
                    & $add 'profile-present' 'pass' 'profile.json exists' @()
                    & $profileFresh
                    $prof = Read-SkrJson -Path $pp
                    $allowed = @($config.gates.G0.allowHealth)
                    $blockers = @($prof.health | Where-Object { $_.severity -eq 'blocker' -and $allowed -notcontains $_.id -and $_.id -ne 'REPO-H01' })
                    $others = @($prof.health | Where-Object { $_.severity -ne 'blocker' -or $allowed -contains $_.id })
                    if ($blockers.Count) { & $add 'profile-health' 'fail' "$($blockers.Count) blocker(s): fix them in an approved slice or allow them in config.gates.G0.allowHealth" @($blockers | ForEach-Object { "$($_.id): $($_.message)" }) }
                    else { & $add 'profile-health' 'pass' "no blockers ($($others.Count) other item(s))" @($others | ForEach-Object { "$($_.id) [$($_.severity)]: $($_.message)" }) }
                    if ($prof.repository.solutionSelection -eq 'ambiguous') { & $add 'solution-selected' 'fail' "Multiple solutions; run 'speckit-radzen detect -Solution <path>' (P-13.8)." @($prof.repository.solutions) }
                    else { & $add 'solution-selected' 'pass' "$($prof.repository.solution) ($($prof.repository.solutionSelection))" @() }
                }
                $avail = $state.mcp.availability
                if ($avail -eq 'unknown' -or -not $avail) { & $add 'mcp-availability-recorded' 'fail' "Record MCP availability: speckit-radzen state -Feature $($f.Number) -McpAvailability available|unavailable|quota-exhausted" @() }
                else { & $add 'mcp-availability-recorded' 'pass' $avail @() }
                $mcp = Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel
                if ($mcp.Status -eq 'secret-in-repo') { & $add 'mcp-no-secret' 'fail' $mcp.Advice @($mcp.Servers | Where-Object KeyKind -eq 'literal' | ForEach-Object File) }
                else { & $add 'mcp-no-secret' 'pass' "mcp-check: $($mcp.Status)" @() }
                if (Test-Path (Join-Path $stateRoot 'profile.json')) {
                    Write-SkrJson -Path (Join-Path $gatesDir 'dependencies.json') -InputObject (Get-SkrDependencySnapshot -Repository $repo)
                    & $add 'dependency-snapshot' 'pass' 'gates/dependencies.json' @()
                }
            }
            'G1' { & $profileFresh; & $lintCheck 'discovery-lint' @('discovery') }
            'G2' {
                & $lintCheck 'spec-lint' @('spec')
                & $lintCheck 'gap-analysis-lint' @('gap-analysis')
                & $lintCheck 'clarifications-lint' @('clarifications')
            }
            'G3' {
                & $profileFresh
                & $lintCheck 'plan-lint' @('plan')
                & $lintCheck 'test-scenarios-lint' @('test-scenarios')
            }
            'G4' {
                & $lintCheck 'tasks-lint' @('tasks')
                $an = @(Invoke-SkrAnalysis -Feature $f.Id -Repository $repo)
                $errs = @($an | Where-Object severity -eq 'error')
                $warns = @($an | Where-Object severity -eq 'warning')
                if ($errs.Count) { & $add 'analysis' 'fail' "$($errs.Count) consistency error(s); see analysis.md" @($errs | ForEach-Object message) }
                elseif ($warns.Count) { & $add 'analysis' 'waived' "$($warns.Count) warning(s) (approved fallbacks or mismatches); see analysis.md" @($warns | ForEach-Object message) }
                else { & $add 'analysis' 'pass' 'traceability complete, evidence sufficient' @() }
            }
            'G5' {
                $g5 = $config.gates.G5
                if (-not $g5.enabled) { & $add 'build' 'waived' 'G5 disabled in config (gates.G5.enabled = false).' @(); break }
                $baselinePath = Join-Path $stateRoot 'baseline' 'build-baseline.json'
                if (-not (Test-Path $baselinePath)) { & $add 'baseline' 'error' "No build baseline. Run 'speckit-radzen baseline' (ideally before the first change)." @(); break }
                $baseline = Read-SkrJson -Path $baselinePath
                $run = Invoke-SkrBuildAndTest -Repository $repo -G5Config $g5
                if ($run.buildTimedOut) { & $add 'build' 'error' "Build timed out after $($g5.timeoutMinutes) min." @(); break }
                if ($run.buildExitCode -ne 0) {
                    $errText = @($run.errors | Select-Object -First 20 | ForEach-Object { "$($_.file)($($_.line)): $($_.code) $($_.message)" })
                    if (-not $errText.Count) { $errText = @($run.buildOutputTail) }
                    & $add 'build' 'fail' "Build failed: $(@($run.errors).Count) error(s) in $($run.target)" $errText
                }
                else { & $add 'build' 'pass' "$($run.target) built" @() }
                $known = @{}
                foreach ($w in @($baseline.warnings)) { $known["$($w.file)|$($w.code)|$($w.message)"] = $true }
                $new = @($run.warnings | Where-Object { -not $known.ContainsKey("$($_.file)|$($_.code)|$($_.message)") })
                $allowed = [int]$g5.allowNewWarnings
                if ($new.Count -gt $allowed) { & $add 'new-warnings' 'fail' "$($new.Count) new warning(s) (allowed: $allowed)" @($new | Select-Object -First 30 | ForEach-Object { "$($_.file)($($_.line)): $($_.code) $($_.message)" }) }
                else { & $add 'new-warnings' 'pass' "$($new.Count) new, $(@($run.warnings).Count) total" @() }
                if ($run.buildExitCode -eq 0) {
                    if (-not $g5.runTests) { & $add 'tests' 'waived' 'Tests disabled in config (gates.G5.runTests = false).' @() }
                    elseif (-not $run.tests -or $run.tests.Total -eq 0) {
                        if ($run.testExitCode -eq 0) { & $add 'tests' 'pass' 'No tests discovered.' @() }
                        else { & $add 'tests' 'error' "dotnet test failed without results (exit $($run.testExitCode))." @($run.testOutputTail) }
                    }
                    else {
                        $preExisting = @($baseline.failingTests)
                        $newFailures = @($run.tests.FailedTests | Where-Object { $preExisting -notcontains $_ })
                        $oldFailures = @($run.tests.FailedTests | Where-Object { $preExisting -contains $_ })
                        $summary = "$($run.tests.Passed)/$($run.tests.Total) passed, $($run.tests.Failed) failed, $($run.tests.Skipped) skipped"
                        if ($newFailures.Count) { & $add 'tests' 'fail' "$summary; $($newFailures.Count) failure(s) not in baseline (classify: introduced / pre-existing (prove) / unknown = stop)" $newFailures }
                        elseif ($oldFailures.Count) { & $add 'tests' 'waived' "$summary; all failures are pre-existing (baseline)" $oldFailures }
                        elseif ($run.testExitCode -ne 0) { & $add 'tests' 'fail' "dotnet test exit code $($run.testExitCode) ($summary)" @($run.testOutputTail) }
                        else { & $add 'tests' 'pass' $summary @() }
                    }
                }
                else { & $add 'tests' 'skipped' 'Build failed; tests not run.' @() }
                # compile-verify evidence cited by the slice's tasks
                if (-not @($checks | Where-Object { $_.status -in 'fail', 'error' }).Count) {
                    $tasks = Get-SkrTaskModel -FeaturePath $f.Path
                    $ids = @(@(if ($tasks) { $tasks.Tasks | Where-Object { -not $Slice -or $_.Slice -eq $Slice } | ForEach-Object Mcp }) | Select-Object -Unique)
                    $evPath = Join-Path $f.Path 'mcp-evidence.json'
                    $doc = Read-SkrJson -Path $evPath -AsHashtable
                    $marked = 0
                    if ($doc -and $ids.Count) {
                        foreach ($e in $doc.entries) { if ($ids -contains $e.id -and $e.status -eq 'confirmed' -and -not $e.compileVerified) { $e.compileVerified = $true; $marked++ } }
                        Write-SkrJson -Path $evPath -InputObject $doc
                        Write-SkrEvidenceMarkdown -FeaturePath $f.Path
                    }
                    & $add 'evidence-compile-verified' 'pass' "$marked evidence entr$(if ($marked -eq 1) { 'y' } else { 'ies' }) marked compile-verified ($($ids.Count) cited)" @($ids)
                }
            }
            'G6' {
                $scan = Invoke-SkrAntiPatternScan -Repository $repo -Feature $f.Id
                $failOn = @($config.gates.G6.failOn)
                $failing = @($scan.findings | Where-Object { -not $_.waived -and $failOn -contains $_.severity })
                $ev = @($scan.findings | Where-Object { -not $_.waived } | ForEach-Object { "[$($_.severity)] $($_.rule) $($_.file):$($_.line) — $($_.message)" })
                if ($failing.Count) { & $add 'scan' 'fail' "$($failing.Count) finding(s) at $($failOn -join '/') severity in $($scan.scannedFiles) file(s); see gates/scan.md" $ev }
                elseif ($scan.summary.waived) { & $add 'scan' 'waived' "clean; $($scan.summary.waived) waived, $($scan.summary.minor) minor ($($scan.scope))" @($scan.findings | Where-Object waived | ForEach-Object { "$($_.rule) $($_.file):$($_.line) — $($_.waiver)" }) }
                else { & $add 'scan' 'pass' "clean ($($scan.scannedFiles) file(s), $($scan.scope); $($scan.summary.minor) minor)" $ev }
            }
            'G7' {
                $open = @($state.slices.Keys | Where-Object { $state.slices[$_].status -ne 'done' -or $state.slices[$_].g5 -notin 'pass', 'waived' -or $state.slices[$_].g6 -notin 'pass', 'waived' })
                if (-not $state.slices.Count) { & $add 'slices-verified' 'fail' 'No slices recorded; enter the implement phase first.' @() }
                elseif ($open.Count) { & $add 'slices-verified' 'fail' "Slices without passing G5/G6 or not done: $($open -join ', ')" @() }
                else { & $add 'slices-verified' 'pass' "$($state.slices.Count) slice(s) verified" @() }
                & $lintCheck 'review-lint' @('review')
                $snapPath = Join-Path $gatesDir 'dependencies.json'
                if (-not (Test-Path $snapPath)) { & $add 'dependency-drift' 'error' 'No dependency snapshot from G0. Re-run G0.' @() }
                else {
                    $before = Read-SkrJson -Path $snapPath -AsHashtable
                    $after = Get-SkrDependencySnapshot -Repository $repo
                    $changes = @()
                    foreach ($p in $after.projects) { if ($before.projects -notcontains $p) { $changes += @{ key = $p; text = "new project $p" } } }
                    foreach ($k in $after.packages.Keys) {
                        $id = ($k -split '\|')[-1]
                        if (-not $before.packages.ContainsKey($k)) { $changes += @{ key = $id; text = "new package $id in $(($k -split '\|')[0])" } }
                        elseif ("$($before.packages[$k])" -ne "$($after.packages[$k])") { $changes += @{ key = $id; text = "$id changed $($before.packages[$k]) -> $($after.packages[$k]) in $(($k -split '\|')[0])" } }
                    }
                    $plan = Get-SkrPlanModel -FeaturePath $f.Path
                    $approvedText = if ($plan) { "$($plan.Dependencies)" } else { '' }
                    $unapproved = @($changes | Where-Object { $approvedText -notmatch [regex]::Escape([System.IO.Path]::GetFileNameWithoutExtension($_.key)) })
                    if ($unapproved.Count) { & $add 'dependency-drift' 'fail' "$($unapproved.Count) dependency change(s) not approved in plan.md (AP-ARC-01 / AP-AGT-02)" @($unapproved | ForEach-Object text) }
                    elseif ($changes.Count) { & $add 'dependency-drift' 'pass' "$($changes.Count) approved change(s)" @($changes | ForEach-Object text) }
                    else { & $add 'dependency-drift' 'pass' 'no dependency changes' @() }
                }
            }
            'G8' {
                $missing = @(foreach ($g in 'G0', 'G1', 'G2', 'G3', 'G4', 'G7') { if (-not $state.gates.ContainsKey($g) -or $state.gates[$g].status -notin 'pass', 'waived') { $g } })
                $sliceIssues = @($state.slices.Keys | Where-Object { $state.slices[$_].g5 -notin 'pass', 'waived' -or $state.slices[$_].g6 -notin 'pass', 'waived' })
                if ($missing.Count -or $sliceIssues.Count -or -not $state.slices.Count) { & $add 'gates-passed' 'fail' "Not passed: $((@($missing) + @($sliceIssues | ForEach-Object { "G5/G6 for $_" })) -join ', ')$(if (-not $state.slices.Count) { ' (no slices)' })" @() }
                else { & $add 'gates-passed' 'pass' 'G0–G7 passed' @() }
                $current = Get-SkrCodeFingerprint -Repository $repo
                $stale = @(foreach ($g in 'G5', 'G6', 'G7') { if ($state.gates.ContainsKey($g) -and $state.gates[$g].codeFingerprint -ne $current) { $g } })
                if ($stale.Count) { & $add 'code-unchanged-since-gates' 'fail' "Code changed after $($stale -join ', '); re-run them." @() }
                else { & $add 'code-unchanged-since-gates' 'pass' "code fingerprint $($current.Substring(0, 12))" @() }
                $tasks = Get-SkrTaskModel -FeaturePath $f.Path
                $openTasks = @(if ($tasks) { $tasks.Tasks | Where-Object { -not $_.Done } | ForEach-Object Id })
                if (-not $tasks -or -not $tasks.Tasks.Count) { & $add 'tasks-complete' 'fail' 'No tasks found.' @() }
                elseif ($openTasks.Count) { & $add 'tasks-complete' 'fail' "$($openTasks.Count) open task(s)" $openTasks }
                else { & $add 'tasks-complete' 'pass' "$($tasks.Tasks.Count) task(s) done" @() }
                & $lintCheck 'review-lint' @('review')
                & $add 'report' 'pass' 'gate-report.md' @()
            }
        }
    }
    catch {
        & $add 'exception' 'error' $_.Exception.Message @($_.ScriptStackTrace)
    }

    $statuses = @($checks | ForEach-Object status)
    $overall = if ($statuses -contains 'error') { 'error' } elseif ($statuses -contains 'fail') { 'fail' } elseif ($statuses -contains 'waived') { 'waived' } else { 'pass' }
    $exit = switch ($overall) { 'pass' { 0 } 'fail' { 1 } 'waived' { 2 } default { 3 } }
    $fingerprint = if ($Gate -in 'G5', 'G6', 'G7', 'G8') { Get-SkrCodeFingerprint -Repository $repo } else { $null }
    $result = [ordered]@{
        schemaVersion = 1; gate = $Gate; name = $def.name; feature = $f.Id; slice = $(if ($Slice) { $Slice } else { $null })
        status = $overall; exitCode = $exit; startedAt = $started; finishedAt = (Get-SkrTimestamp); kitVersion = (Get-SkrKitVersion)
        codeFingerprint = $fingerprint; checks = $checks.ToArray()
    }
    $json = $result | ConvertTo-Json -Depth 20
    $schemaErrors = Test-SkrJsonSchema -Json $json -SchemaName 'gate-result'
    if ($schemaErrors.Count) { throw "Gate result does not match schema: $($schemaErrors -join '; ')" }
    Write-SkrText -Path (Join-Path $gatesDir "$Gate.json") -Content $json
    if ($Slice -and $Gate -in 'G5', 'G6') { Write-SkrText -Path (Join-Path $gatesDir "$Gate-$Slice.json") -Content $json }

    # state
    $state = Get-SkrState -FeaturePath $f.Path
    if ($Gate -eq 'G0' -and -not $state.baseRef -and (Get-Command git -ErrorAction Ignore) -and (Test-Path (Join-Path $repo '.git'))) {
        $head = & git -C $repo rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { $state.baseRef = "$head".Trim() }
    }
    $state.gates[$Gate] = @{ status = $overall; at = $result.finishedAt; slice = $result.slice; codeFingerprint = $fingerprint }
    if ($Gate -in 'G5', 'G6') {
        $targets = @(if ($Slice) { $Slice } else { $state.slices.Keys | Where-Object { $state.slices[$_].status -ne 'done' } })
        foreach ($s in $targets) {
            if (-not $state.slices.ContainsKey($s)) { $state.slices[$s] = @{ status = 'pending'; at = $null; g5 = $null; g6 = $null } }
            $state.slices[$s][$Gate.ToLowerInvariant()] = $overall
            if ($state.slices[$s].status -eq 'pending') { $state.slices[$s].status = 'in-progress' }
        }
    }
    if ($Gate -eq 'G8' -and $overall -in 'pass', 'waived') { $state.phase = 'done' }
    Save-SkrState -FeaturePath $f.Path -State $state -EventName "gate:$Gate=$overall" -Detail $(if ($Slice) { $Slice } else { $null })
    Write-SkrGateReport -FeaturePath $f.Path
    [pscustomobject]$result
}
