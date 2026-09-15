function Invoke-SkrAnalysis {
    <#
    .SYNOPSIS
        Cross-artifact consistency analysis (phase 06). Writes analysis.md and returns the findings.
    #>
    [CmdletBinding()]
    param(
        [string] $Feature,
        [string] $Repository = (Get-Location).Path,
        [switch] $NoWrite
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $f = Resolve-SkrFeature -Repository $repo -Feature $Feature
    $config = Get-SkrConfig -Repository $repo
    $maxRank = [int]$config.gates.G4.maxEvidenceRank

    $spec = Get-SkrSpecModel -FeaturePath $f.Path
    $plan = Get-SkrPlanModel -FeaturePath $f.Path
    $tasks = Get-SkrTaskModel -FeaturePath $f.Path
    $ts = Get-SkrTestScenarioModel -FeaturePath $f.Path
    $evidence = @(Get-SkrEvidenceModel -FeaturePath $f.Path)

    $findings = [System.Collections.Generic.List[object]]::new()
    $add = { param($sev, $rule, $msg) $findings.Add([pscustomobject]@{ severity = $sev; rule = $rule; message = $msg }) }

    foreach ($pair in @(@('spec.md', $spec), @('plan.md', $plan), @('tasks.md', $tasks), @('test-scenarios.md', $ts))) {
        if ($null -eq $pair[1]) { & $add 'error' 'missing-artifact' "$($pair[0]) is missing." }
    }

    $matrix = @()
    if ($spec) {
        foreach ($fr in $spec.FR) {
            $acs = @($spec.AC | Where-Object { $_.Covers -contains $fr } | ForEach-Object Id)
            $tss = @(if ($ts) { $ts.Scenarios | Where-Object { @($_.Covers | Where-Object { $acs -contains $_ }).Count } | ForEach-Object Id })
            $tks = @(if ($tasks) { $tasks.Tasks | Where-Object { $_.Covers -contains $fr -or @($_.CoversAC | Where-Object { $acs -contains $_ }).Count } | ForEach-Object Id })
            $sls = @(if ($plan) { $plan.Slices | Where-Object { $_.Covers -contains $fr } | ForEach-Object Id })
            $matrix += [pscustomobject]@{ FR = $fr; AC = $acs; TS = $tss; Slices = $sls; Tasks = $tks }
            if (-not $acs.Count) { & $add 'error' 'fr-without-ac' "$fr has no acceptance criterion." }
            if ($ts -and -not $tss.Count) { & $add 'error' 'fr-without-test' "$fr has no test scenario (via its ACs)." }
            if ($tasks -and -not $tks.Count) { & $add 'error' 'fr-without-task' "$fr is not covered by any task." }
            if ($plan -and -not $sls.Count) { & $add 'error' 'fr-without-slice' "$fr is not covered by any slice." }
        }
        if ($tasks) {
            foreach ($t in $tasks.Tasks) {
                foreach ($ref in $t.Covers) { if ($spec.FR -notcontains $ref) { & $add 'error' 'orphan-task' "$($t.Id) references unknown $ref." } }
                foreach ($ref in $t.CoversAC) { if (@($spec.AC.Id) -notcontains $ref) { & $add 'error' 'orphan-task' "$($t.Id) references unknown $ref." } }
            }
        }
        if ($ts) {
            foreach ($s in $ts.Scenarios) { foreach ($ref in $s.Covers) { if (@($spec.AC.Id) -notcontains $ref) { & $add 'error' 'orphan-scenario' "$($s.Id) references unknown $ref." } } }
        }
        if ($plan) {
            foreach ($s in $plan.Slices) { foreach ($ref in $s.Covers) { if ($spec.FR -notcontains $ref) { & $add 'error' 'orphan-slice' "$($s.Id) references unknown $ref." } } }
        }
        if ($spec.Clarify.Count) { & $add 'error' 'open-clarification' "spec.md still has $($spec.Clarify.Count) [NEEDS CLARIFICATION] marker(s)." }
    }

    if ($plan -and $tasks) {
        foreach ($s in $plan.Slices) {
            if (-not ($tasks.Tasks | Where-Object Slice -eq $s.Id)) { & $add 'error' 'slice-without-task' "$($s.Id) has no tasks." }
        }
        foreach ($t in $tasks.Tasks) {
            if ($t.Slice -and @($plan.Slices.Id) -notcontains $t.Slice) { & $add 'error' 'task-without-slice' "$($t.Id) is in unknown slice $($t.Slice)." }
        }
    }

    # MCP evidence
    $evidenceIds = @($evidence | ForEach-Object id)
    $refs = @()
    if ($plan) { $refs += $plan.McpRefs }
    if ($tasks) { $refs += @($tasks.Tasks | ForEach-Object Mcp) }
    foreach ($ref in ($refs | Select-Object -Unique)) {
        if ($evidenceIds -notcontains $ref) { & $add 'error' 'missing-evidence' "$ref is referenced but not in mcp-evidence.json." }
    }
    foreach ($e in $evidence) {
        if ($e.status -eq 'superseded') { continue }
        if ($e.status -eq 'conflict') { & $add 'error' 'evidence-conflict' "$($e.id) ($($e.component)) is an unresolved conflict." ; continue }
        if ($e.rank -gt $maxRank) {
            if ($e.rank -le 4 -and $e.fallbackApproved) { & $add 'warning' 'evidence-fallback' "$($e.id) ($($e.component)) relies on an approved rank-$($e.rank) fallback: $($e.fallbackReason)" }
            else { & $add 'error' 'weak-evidence' "$($e.id) ($($e.component)) has rank $($e.rank) (source: $($e.source)); maximum allowed is $maxRank." }
        }
    }
    if ($plan) {
        foreach ($r in $plan.McpRows) {
            $name = "$(@($r.Values)[0])"
            if ($name -match '^(?i)(none|n/a)') { continue }
            $ids = @(Get-SkrIdSet -Text $r['Evidence'] -Prefix 'MCP')
            foreach ($id in $ids) {
                $e = $evidence | Where-Object id -eq $id
                if ($e -and $name -notmatch [regex]::Escape($e.component) -and $e.component -notmatch [regex]::Escape(($name -split '[\s/]')[0])) {
                    & $add 'warning' 'evidence-mismatch' "Plan row '$name' cites $id, which is about '$($e.component)'."
                }
            }
        }
    }

    $errors = @($findings | Where-Object severity -eq 'error').Count
    if (-not $NoWrite) {
        $sb = [System.Text.StringBuilder]::new()
        $null = $sb.AppendLine("# Analysis: $($f.Id)")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine("- **Generated:** $(Get-SkrTimestamp) by ``speckit-radzen analyze``")
        $null = $sb.AppendLine("- **Result:** $(if ($errors) { "$errors error(s)" } else { 'no errors' }), $(@($findings | Where-Object severity -eq 'warning').Count) warning(s)")
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('## Traceability matrix')
        $null = $sb.AppendLine()
        if ($matrix.Count) { $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows $matrix -Columns 'FR', 'AC', 'TS', 'Slices', 'Tasks')) } else { $null = $sb.AppendLine('No functional requirements found.') }
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('## Automated findings')
        $null = $sb.AppendLine()
        if ($findings.Count) { $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows $findings -Columns 'severity', 'rule', 'message')) } else { $null = $sb.AppendLine('None.') }
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('## MCP evidence summary')
        $null = $sb.AppendLine()
        if ($evidence.Count) { $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows $evidence -Columns 'id', 'component', 'source', 'rank', 'status')) } else { $null = $sb.AppendLine('No evidence recorded.') }
        $null = $sb.AppendLine()
        $existing = Read-SkrArtifactText -FeaturePath $f.Path -File 'analysis.md'
        $manual = if ($existing) { Get-SkrMarkdownSection -Markdown $existing -Title 'Manual findings' } else { $null }
        $null = $sb.AppendLine('## Manual findings')
        if ($manual) { $null = $sb.Append($manual.TrimEnd()); $null = $sb.AppendLine() }
        else {
            $null = $sb.AppendLine()
            $null = $sb.AppendLine('<!-- Semantic checks (plan vs spec contradictions, scope creep, authorization enforcement). This section is preserved when the analysis is regenerated. -->')
            $null = $sb.AppendLine()
            $null = $sb.AppendLine('- Not reviewed yet.')
        }
        Write-SkrText -Path (Join-Path $f.Path 'analysis.md') -Content $sb.ToString()
    }
    return $findings.ToArray()
}
