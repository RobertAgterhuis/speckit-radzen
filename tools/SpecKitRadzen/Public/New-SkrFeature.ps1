function New-SkrFeature {
    <#
    .SYNOPSIS
        Creates specs/NNN-name/ with state.json and the artifact templates.
    .EXAMPLE
        New-SkrFeature -Name 'Customer search' -Repository .
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)][string] $Name,
        [string] $Repository = (Get-Location).Path
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $root = Get-SkrSpecsRoot -Repository $repo
    $slug = ConvertTo-SkrSlug -Name $Name

    $existing = Get-SkrFeatureFolder -Repository $repo
    $dup = $existing | Where-Object { $_.Name.Substring(4) -eq $slug }
    if ($dup) { throw "A feature named '$slug' already exists: $($dup.Name)" }
    $next = 1
    if ($existing) { $next = ([int](@($existing)[-1].Name.Substring(0, 3))) + 1 }
    if ($next -gt 999) { throw 'Feature numbering exhausted (999).' }
    $number = '{0:D3}' -f $next
    $id = "$number-$slug"
    $path = Join-Path $root $id

    if (-not $PSCmdlet.ShouldProcess($path, 'Create feature folder')) { return }

    $null = New-Item -ItemType Directory -Path (Join-Path $path 'gates') -Force
    $templates = Join-Path (Get-SkrCoreRoot) 'templates'
    foreach ($t in 'discovery.md', 'spec.md', 'gap-analysis.md', 'clarifications.md', 'plan.md', 'test-scenarios.md', 'tasks.md', 'review.md') {
        $content = Get-Content (Join-Path $templates $t) -Raw
        $content = $content.Replace('{{feature title}}', $Name).Replace('{{NNN-name}}', $id).Replace('{{NNN}}', $number)
        Write-SkrText -Path (Join-Path $path $t) -Content $content
    }
    Write-SkrJson -Path (Join-Path $path 'mcp-evidence.json') -InputObject ([ordered]@{ schemaVersion = 1; feature = $id; entries = @() })

    $now = Get-SkrTimestamp
    $state = @{
        schemaVersion = 1; feature = $id; number = $number; name = $Name; phase = 'bootstrap'
        created = $now; updated = $now
        mcp = @{ availability = 'unknown'; recordedAt = $null; note = $null }
        gates = @{}; slices = @{}; history = @()
        baseRef = $null
    }
    if ((Get-Command git -ErrorAction Ignore) -and (Test-Path (Join-Path $repo '.git'))) {
        $head = & git -C $repo rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $head) { $state.baseRef = "$head".Trim() }
    }
    Save-SkrState -FeaturePath $path -State $state -EventName 'created' -Detail $Name

    [pscustomobject]@{ Id = $id; Number = $number; Path = $path }
}
