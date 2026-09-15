function Set-SkrFeaturePhase {
    <#
    .SYNOPSIS
        Moves a feature to a phase (enforcing entry gates), completes a slice, or records MCP availability.
    .EXAMPLE
        Set-SkrFeaturePhase -Feature 001 -Phase plan
    .EXAMPLE
        Set-SkrFeaturePhase -Feature 001 -CompleteSlice S-01
    .EXAMPLE
        Set-SkrFeaturePhase -Feature 001 -McpAvailability available
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('bootstrap', 'discover', 'specify', 'clarify', 'plan', 'tasks', 'analyze', 'implement', 'review')]
        [string] $Phase,
        [string] $Feature,
        [ValidatePattern('^S-[0-9]{2}$')][string] $CompleteSlice,
        [ValidateSet('available', 'unavailable', 'quota-exhausted', 'unknown')][string] $McpAvailability,
        [string] $Note,
        [string] $Repository = (Get-Location).Path,
        [switch] $Force
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $f = Resolve-SkrFeature -Repository $repo -Feature $Feature
    $state = Get-SkrState -FeaturePath $f.Path
    $events = @()

    if ($McpAvailability) {
        $state.mcp = @{ availability = $McpAvailability; recordedAt = (Get-SkrTimestamp); note = $Note }
        $events += "mcp:$McpAvailability"
    }

    if ($CompleteSlice) {
        if ($state.phase -ne 'implement' -and -not $Force) { throw "Slices can only be completed in the implement phase (current: $($state.phase))." }
        $slice = if ($state.slices.ContainsKey($CompleteSlice)) { $state.slices[$CompleteSlice] } else { @{ status = 'pending' } }
        foreach ($g in 'g5', 'g6') {
            if (-not $Force -and $slice[$g] -notin 'pass', 'waived') {
                throw "Slice $CompleteSlice cannot be completed: $($g.ToUpper()) has not passed for this slice (status: $(if ($slice[$g]) { $slice[$g] } else { 'not run' }))."
            }
        }
        $slice.status = 'done'; $slice.at = Get-SkrTimestamp
        $state.slices[$CompleteSlice] = $slice
        $events += "slice-done:$CompleteSlice"
    }

    if ($Phase) {
        $current = $script:SkrPhases.IndexOf($state.phase)
        $target = $script:SkrPhases.IndexOf($Phase)
        if ($target -gt $current + 1 -and -not $Force) {
            throw "Cannot skip from '$($state.phase)' to '$Phase'. Next phase is '$($script:SkrPhases[$current + 1])'. Use -Force only when the user agreed to skip phases (record why with -Note)."
        }
        $required = $script:SkrPhaseEntryGate[$Phase]
        if ($required -and $target -gt $current -and -not $Force) {
            $g = $state.gates[$required]
            if (-not $g -or $g.status -notin 'pass', 'waived') {
                throw "Cannot enter '$Phase': gate $required has not passed. Run 'speckit-radzen gate $required -Feature $($f.Number)'."
            }
        }
        if ($Phase -eq 'implement' -and $state.slices.Count -eq 0) {
            foreach ($s in (Get-SkrPlanSlice -FeaturePath $f.Path)) { $state.slices[$s] = @{ status = 'pending'; at = $null; g5 = $null; g6 = $null } }
        }
        if ($Phase -eq 'review' -and -not $Force) {
            $open = @($state.slices.Keys | Where-Object { $state.slices[$_].status -ne 'done' })
            if ($open.Count) { throw "Cannot enter review: slices not done: $($open -join ', ')." }
        }
        $from = $state.phase
        $state.phase = $Phase
        $detail = "$from -> $Phase"
        if ($Force) { $detail += ' (forced)' }
        if ($Note) { $detail += " — $Note" }
        $events += "phase:$detail"
    }

    if (-not $events) { throw 'Nothing to do. Specify -Phase, -CompleteSlice or -McpAvailability.' }
    if ($PSCmdlet.ShouldProcess($f.Id, ($events -join ', '))) {
        Save-SkrState -FeaturePath $f.Path -State $state -EventName ($events -join '; ') -Detail $Note
    }
    Get-SkrFeatureState -Feature $f.Id -Repository $repo
}

function Get-SkrPlanSlice {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $plan = Join-Path $FeaturePath 'plan.md'
    if (-not (Test-Path $plan)) { return @() }
    $text = Get-Content $plan -Raw
    return @([regex]::Matches($text, '(?m)^#{2,4}\s+(S-[0-9]{2})\b') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
}
