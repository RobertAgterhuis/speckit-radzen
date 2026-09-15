function Get-SkrFeatureState {
    <#
    .SYNOPSIS
        Returns the state of one feature, or a summary of all features with -All.
    #>
    [CmdletBinding()]
    param(
        [string] $Feature,
        [string] $Repository = (Get-Location).Path,
        [switch] $All
    )
    $repo = Resolve-SkrRepository -Path $Repository
    if ($All) {
        foreach ($folder in (Get-SkrFeatureFolder -Repository $repo)) {
            $s = Read-SkrJson -Path (Join-Path $folder.FullName 'state.json')
            [pscustomobject]@{
                Feature = $folder.Name
                Phase   = if ($s) { $s.phase } else { '(no state)' }
                Gates   = if ($s -and $s.gates) { (($s.gates.PSObject.Properties | Sort-Object Name | ForEach-Object { "$($_.Name):$($_.Value.status)" }) -join ' ') } else { '' }
                Updated = if ($s) { $s.updated } else { $null }
            }
        }
        return
    }
    $f = Resolve-SkrFeature -Repository $repo -Feature $Feature
    $state = Get-SkrState -FeaturePath $f.Path
    [pscustomobject]@{
        Feature  = $state.feature
        Path     = $f.Path
        Phase    = $state.phase
        Mcp      = $state.mcp.availability
        Gates    = $state.gates
        Slices   = $state.slices
        NextStep = Get-SkrNextStep -State $state
        Updated  = $state.updated
    }
}

function Get-SkrNextStep {
    param([Parameter(Mandatory)][hashtable] $State)
    $g = $State.gates
    $passed = { param($id) $g.ContainsKey($id) -and $g[$id].status -in 'pass', 'waived' }
    switch ($State.phase) {
        'bootstrap' { if (& $passed 'G0') { return 'phase discover' } else { return 'gate G0 (after detect + mcp-check)' } }
        'discover' { if (& $passed 'G1') { return 'phase specify' } else { return 'write discovery.md, then gate G1' } }
        'specify' { return 'write spec.md + gap-analysis.md, lint, then phase clarify' }
        'clarify' { if (& $passed 'G2') { return 'phase plan' } else { return 'resolve clarifications, then gate G2' } }
        'plan' { if (& $passed 'G3') { return 'phase tasks' } else { return 'write plan.md + evidence + test-scenarios.md, then gate G3' } }
        'tasks' { return 'write tasks.md, lint, then phase analyze' }
        'analyze' { if (& $passed 'G4') { return 'phase implement' } else { return 'analyze, fix findings, then gate G4' } }
        'implement' {
            $open = @($State.slices.Keys | Where-Object { $State.slices[$_].status -ne 'done' } | Sort-Object)
            if ($open.Count) { return "implement slice $($open[0]); gate G5 + G6; phase implement -CompleteSlice $($open[0])" }
            return 'phase review'
        }
        'review' { if (& $passed 'G7') { return 'gate G8' } else { return 'write review.md, then gate G7' } }
        'done' { return 'none (feature done)' }
    }
}
