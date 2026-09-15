function Test-SkrArtifact {
    <#
    .SYNOPSIS
        Lints feature artifacts against the template contract.
    .PARAMETER Artifact
        One or more of: discovery, spec, gap-analysis, clarifications, plan, test-scenarios, tasks, review. Default: all that exist.
    .PARAMETER Strict
        Treats open clarification markers and unanswered checklist items as errors (used by gates).
    .OUTPUTS
        Lint findings (artifact, severity, rule, message).
    #>
    [CmdletBinding()]
    param(
        [string] $Feature,
        [ValidateSet('discovery', 'spec', 'gap-analysis', 'clarifications', 'plan', 'test-scenarios', 'tasks', 'review')]
        [string[]] $Artifact,
        [switch] $Strict,
        [string] $Repository = (Get-Location).Path
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $f = Resolve-SkrFeature -Repository $repo -Feature $Feature
    $rules = (Read-SkrJson -Path (Join-Path (Get-SkrCoreRoot) 'templates' 'lint-rules.json')).artifacts
    $names = if ($Artifact) { $Artifact } else { @($rules.PSObject.Properties.Name | Where-Object { Test-Path (Join-Path $f.Path $rules.$_.file) }) }
    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($name in $names) {
        $file = $rules.$name.file
        $raw = Read-SkrArtifactText -FeaturePath $f.Path -File $file
        if ($null -eq $raw) { $findings.Add((New-SkrLintFinding $name 'error' 'missing' "$file does not exist.")); continue }
        $text = Remove-SkrHtmlComment $raw
        $headings = @(Get-SkrMarkdownHeading -Markdown $text)
        foreach ($section in $rules.$name.requiredSections) {
            if ($headings -notcontains $section) { $findings.Add((New-SkrLintFinding $name 'error' 'section' "Required section '$section' is missing.")) }
        }
        $placeholders = [regex]::Matches($text, '\{\{[^}]*\}\}')
        if ($placeholders.Count) {
            $sample = ($placeholders | Select-Object -First 3 | ForEach-Object Value) -join ', '
            $findings.Add((New-SkrLintFinding $name 'error' 'placeholder' "$($placeholders.Count) template placeholder(s) remain, e.g. $sample"))
        }
        foreach ($finding in (& "Test-SkrArtifact_$($name -replace '-', '')" -FeaturePath $f.Path -Text $text -Strict:$Strict)) { $findings.Add($finding) }
    }
    return $findings.ToArray()
}

function Test-SkrArtifact_discovery {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    $blocking = Get-SkrMarkdownSection -Markdown $Text -Title 'Blocking'
    $items = @(("$blocking" -split "`n") | Where-Object { $_ -match '^\s*[-*]\s+\S' -and $_ -notmatch '^\s*[-*]\s+None\.?\s*$' })
    if ($items.Count) {
        $sev = if ($Strict) { 'error' } else { 'warning' }
        New-SkrLintFinding 'discovery' $sev 'blocking-unknowns' "$($items.Count) blocking unknown(s) remain."
    }
    $scope = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $Text -Title 'Scope classification'))
    if (-not $scope.Count) { New-SkrLintFinding 'discovery' 'error' 'scope' 'Scope classification table has no rows.' }
    foreach ($r in $scope) {
        if ($r['Classification'] -notmatch '^(READ-ONLY CONTEXT|LIKELY CHANGE|OUT OF SCOPE|UNKNOWN)$') {
            New-SkrLintFinding 'discovery' 'error' 'scope' "Invalid scope classification '$($r['Classification'])' for '$($r['Area'])'."
        }
    }
    $trace = Get-SkrMarkdownSection -Markdown $Text -Title 'Feature dependency trace'
    if ("$trace" -notmatch '→|->') { New-SkrLintFinding 'discovery' 'error' 'trace' 'Feature dependency trace is empty (expected an arrow chain).' }
}

function Test-SkrArtifact_spec {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    $spec = Get-SkrSpecModel -FeaturePath $FeaturePath
    if (-not $spec.FR.Count) { New-SkrLintFinding 'spec' 'error' 'fr' 'No functional requirements (**FR-###**) found.' }
    $dupes = $spec.FR | Group-Object | Where-Object Count -gt 1
    foreach ($d in $dupes) { New-SkrLintFinding 'spec' 'error' 'fr' "Duplicate requirement ID $($d.Name)." }
    foreach ($ac in $spec.ACWithoutRef) { New-SkrLintFinding 'spec' 'error' 'ac-ref' "$ac does not reference an FR, expected '**$ac** (FR-###)'." }
    $covered = @($spec.AC | ForEach-Object Covers | Select-Object -Unique)
    foreach ($fr in $spec.FR) {
        if ($covered -notcontains $fr) { New-SkrLintFinding 'spec' 'error' 'fr-ac' "$fr has no acceptance criterion." }
    }
    foreach ($ac in $spec.AC) {
        foreach ($ref in $ac.Covers) { if ($spec.FR -notcontains $ref) { New-SkrLintFinding 'spec' 'error' 'ac-ref' "$($ac.Id) references unknown $ref." } }
    }
    $gwt = Get-SkrMarkdownSection -Markdown $Text -Title 'Acceptance criteria'
    foreach ($line in ("$gwt" -split "`n" | Where-Object { $_ -match '\*\*AC-[0-9]{3}\*\*' })) {
        if ($line -notmatch '(?i)\bgiven\b.*\bwhen\b.*\bthen\b') { New-SkrLintFinding 'spec' 'warning' 'ac-format' "Not in Given/When/Then form: $($line.Trim())" }
    }
    if (-not $spec.AuthRows.Count) { New-SkrLintFinding 'spec' 'error' 'authorization' 'Authorization matrix has no rows (P-07).' }
    foreach ($r in $spec.AuthRows) {
        if (-not $r['Enforcement point']) { New-SkrLintFinding 'spec' 'error' 'authorization' "Operation '$($r['Operation'])' has no enforcement point." }
    }
    if (-not $spec.StateRows.Count) { New-SkrLintFinding 'spec' 'error' 'ui-states' 'UI state matrix has no rows (P-08).' }
    foreach ($r in $spec.StateRows) {
        foreach ($k in @($r.Keys)) { if (-not $r[$k]) { New-SkrLintFinding 'spec' 'error' 'ui-states' "UI state '$k' is empty for '$($r[@($r.Keys)[0]])' (write the behaviour or 'n/a – reason')." } }
    }
    if ("$($spec.DataVolume)" -notmatch '(?i)\*\*Bounded:\*\*\s*(yes|no)') { New-SkrLintFinding 'spec' 'error' 'data-volume' "Data volume must state '**Bounded:** yes/no' (P-10)." }
    if ($spec.Clarify.Count) {
        $sev = if ($Strict) { 'error' } else { 'warning' }
        New-SkrLintFinding 'spec' $sev 'clarification' "$($spec.Clarify.Count) open [NEEDS CLARIFICATION] marker(s)."
    }
}

function Test-SkrArtifact_gapanalysis {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    $rows = @(Get-SkrMarkdownTableRow $Text)
    if (-not $rows.Count) { New-SkrLintFinding 'gap-analysis' 'error' 'table' 'Capability table has no rows.' }
}

function Test-SkrArtifact_clarifications {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    foreach ($m in [regex]::Matches($Text, '(?ms)^##\s+(Q-[0-9]{3})\b(.*?)(?=^##\s|\z)')) {
        $decision = [regex]::Match($m.Groups[2].Value, '\*\*Decision:\*\*\s*([^\n]*)').Groups[1].Value.Trim()
        if (-not $decision -or $decision -match '^(tbd|todo|\?)$') {
            $sev = if ($Strict) { 'error' } else { 'warning' }
            New-SkrLintFinding 'clarifications' $sev 'decision' "$($m.Groups[1].Value) has no decision."
        }
    }
}

function Test-SkrArtifact_plan {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    $plan = Get-SkrPlanModel -FeaturePath $FeaturePath
    $present = @{}
    foreach ($r in $plan.Constitution) {
        if ($r['Principle'] -match '^(P-[0-9]{2})') { $present[$Matches[1]] = $r }
    }
    foreach ($n in 1..16) {
        $id = 'P-{0:D2}' -f $n
        if (-not $present.ContainsKey($id)) { New-SkrLintFinding 'plan' 'error' 'constitution' "Constitution check is missing $id."; continue }
        $status = $present[$id]['Status']
        if ($status -notmatch '^(complies|n/a|deviation)$') { New-SkrLintFinding 'plan' 'error' 'constitution' "$id status '$status' must be complies, n/a or deviation." }
        elseif ($status -eq 'deviation' -and -not $present[$id]['Notes']) { New-SkrLintFinding 'plan' 'error' 'constitution' "$id deviation needs a justification and approver in Notes." }
        elseif ($status -eq 'deviation') { New-SkrLintFinding 'plan' 'warning' 'constitution' "$id is a deviation: $($present[$id]['Notes'])" }
    }
    if (-not $plan.Layers.Count) { New-SkrLintFinding 'plan' 'error' 'layers' 'Layer impact table has no rows.' }
    foreach ($r in $plan.Layers) {
        if ($r['Impact'] -notmatch '^(no change|modify|add)$') { New-SkrLintFinding 'plan' 'error' 'layers' "Layer '$($r['Layer'])' impact '$($r['Impact'])' must be no change, modify or add." }
    }
    if (-not $plan.Slices.Count) { New-SkrLintFinding 'plan' 'error' 'slices' 'No vertical slices (### S-##) found.' }
    foreach ($s in $plan.Slices) {
        if (-not $s.Verification) { New-SkrLintFinding 'plan' 'error' 'slices' "$($s.Id) has no verification." }
        if (-not $s.Stop) { New-SkrLintFinding 'plan' 'error' 'slices' "$($s.Id) has no stop conditions." }
        if (-not $s.Covers.Count) { New-SkrLintFinding 'plan' 'error' 'slices' "$($s.Id) does not list the FRs it covers." }
    }
    foreach ($r in $plan.McpRows) {
        $first = @($r.Values)[0]
        if ($first -match '^(none|n/a)' ) { continue }
        if ($r['Evidence'] -notmatch 'MCP-[0-9]{3}') { New-SkrLintFinding 'plan' 'error' 'mcp' "Radzen API '$first' has no MCP-### evidence reference (P-15)." }
    }
    foreach ($r in $plan.Components) {
        if ($r['Component'] -match 'Radzen' -and -not ($plan.McpRows | Where-Object { $_['Component / service'] -and $r['Component'] -match [regex]::Escape(($_['Component / service'] -split '[\s/]')[0]) })) {
            New-SkrLintFinding 'plan' 'warning' 'mcp' "Component '$($r['Component'])' is not listed under Radzen MCP verification."
        }
    }
    if (-not ("$($plan.Dependencies)".Trim())) { New-SkrLintFinding 'plan' 'error' 'dependencies' "Approved dependency changes must list changes or say 'None.'." }
}

function Test-SkrArtifact_testscenarios {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    $ts = Get-SkrTestScenarioModel -FeaturePath $FeaturePath
    if (-not $ts.Scenarios.Count) { New-SkrLintFinding 'test-scenarios' 'error' 'scenarios' 'No TS-### rows found.'; return }
    $spec = Get-SkrSpecModel -FeaturePath $FeaturePath
    if ($spec) {
        $covered = @($ts.Scenarios | ForEach-Object Covers | Select-Object -Unique)
        foreach ($ac in $spec.AC) { if ($covered -notcontains $ac.Id) { New-SkrLintFinding 'test-scenarios' 'error' 'ac-coverage' "$($ac.Id) has no test scenario." } }
    }
}

function Test-SkrArtifact_tasks {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    $model = Get-SkrTaskModel -FeaturePath $FeaturePath
    if (-not $model.Tasks.Count) { New-SkrLintFinding 'tasks' 'error' 'tasks' "No tasks found (expected '- [ ] **T-###** — objective')."; return }
    foreach ($d in ($model.Tasks | Group-Object Id | Where-Object Count -gt 1)) { New-SkrLintFinding 'tasks' 'error' 'tasks' "Duplicate task ID $($d.Name)." }
    $plan = Get-SkrPlanModel -FeaturePath $FeaturePath
    $slices = @(if ($plan) { $plan.Slices.Id })
    foreach ($t in $model.Tasks) {
        if (-not $t.Slice) { New-SkrLintFinding 'tasks' 'error' 'slice' "$($t.Id) has no **Slice:**." }
        elseif ($plan -and $slices -notcontains $t.Slice) { New-SkrLintFinding 'tasks' 'error' 'slice' "$($t.Id) references $($t.Slice), which is not in plan.md." }
        if (-not ($t.Covers.Count + $t.CoversAC.Count)) { New-SkrLintFinding 'tasks' 'error' 'covers' "$($t.Id) does not reference an FR or AC in **Covers:**." }
        if (-not $t.Verify) { New-SkrLintFinding 'tasks' 'error' 'verification' "$($t.Id) has no **Verification:**." }
    }
}

function Test-SkrArtifact_review {
    param([string] $FeaturePath, [string] $Text, [switch] $Strict)
    $checklists = Get-SkrMarkdownSection -Markdown $Text -Title 'Checklists'
    $dod = Get-SkrMarkdownSection -Markdown $Text -Title 'Definition of Done'
    $open = @(("$checklists`n$dod" -split "`n") | Where-Object { $_ -match '^\s*[-*]\s+\[ \]' -and $_ -notmatch '(?i)n/a' })
    if ($open.Count) {
        $sev = if ($Strict) { 'error' } else { 'warning' }
        New-SkrLintFinding 'review' $sev 'checklist' "$($open.Count) checklist item(s) unanswered (tick with evidence or mark 'n/a – reason')."
    }
    $acRows = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $Text -Title 'Acceptance criteria'))
    foreach ($r in $acRows) { if ($r['Satisfied'] -notmatch '^(?i)yes$') { New-SkrLintFinding 'review' 'error' 'ac' "$($r['AC']) is not satisfied ('$($r['Satisfied'])')." } }
    $spec = Get-SkrSpecModel -FeaturePath $FeaturePath
    if ($spec) {
        foreach ($ac in $spec.AC) { if (-not ($acRows | Where-Object { $_['AC'] -eq $ac.Id })) { New-SkrLintFinding 'review' 'error' 'ac' "$($ac.Id) is missing from the review." } }
    }
    $findings = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $Text -Title 'Findings'))
    foreach ($r in $findings) {
        if ($r['Severity'] -match '^(?i)(blocker|major)$' -and $r['Status'] -match '^(?i)open') {
            New-SkrLintFinding 'review' 'error' 'findings' "Open $($r['Severity']) finding: $($r['Finding'])"
        }
    }
}
