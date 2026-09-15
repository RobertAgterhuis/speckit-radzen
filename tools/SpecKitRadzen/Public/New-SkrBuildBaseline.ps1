function New-SkrBuildBaseline {
    <#
    .SYNOPSIS
        Builds the solution and runs tests once to record pre-existing warnings and failing tests.
        G5 compares against this baseline to find *new* warnings and failures.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Repository = (Get-Location).Path,
        [switch] $SkipTests
    )
    $repo = Resolve-SkrRepository -Path $Repository
    $config = Get-SkrConfig -Repository $repo
    if (-not (Test-Path (Join-Path (Get-SkrStateRoot $repo) 'profile.json'))) { $null = Get-SkrProjectProfile -Repository $repo }
    $run = Invoke-SkrBuildAndTest -Repository $repo -G5Config $config.gates.G5 -SkipTests:$SkipTests
    $head = $null
    if ((Get-Command git -ErrorAction Ignore) -and (Test-Path (Join-Path $repo '.git'))) { $head = (& git -C $repo rev-parse HEAD 2>$null) }
    $baseline = [ordered]@{
        schemaVersion = 1
        capturedAt    = Get-SkrTimestamp
        commit        = $head
        target        = $run.target
        buildSucceeded = ($run.buildExitCode -eq 0)
        warnings      = @($run.warnings | Sort-Object file, code, message)
        errors        = @($run.errors)
        failingTests  = @(if ($run.tests) { $run.tests.FailedTests })
        testTotals    = $run.tests
    }
    $path = Join-Path (Get-SkrStateRoot $repo) 'baseline' 'build-baseline.json'
    if ($PSCmdlet.ShouldProcess($path, 'Write build baseline')) { Write-SkrJson -Path $path -InputObject $baseline }
    if (-not $baseline.buildSucceeded) { Write-Warning "The build fails before any change ($(@($run.errors).Count) error(s)). Record this in discovery.md; G5 will fail until the build is green." }
    [pscustomobject]@{
        Path = $path; BuildSucceeded = $baseline.buildSucceeded; Warnings = @($baseline.warnings).Count
        FailingTests = @($baseline.failingTests).Count; Tests = if ($run.tests) { $run.tests.Total } else { $null }
    }
}
