#Requires -Version 7.4
<#
.SYNOPSIS
    Runs the Pester suite (unit + integration) with optional coverage.
.PARAMETER CI
    NUnit XML results and coverage (JaCoCo) in tests/results/; fails the process on test failures.
.PARAMETER IncludeBuild
    Also run the NuGet-dependent end-to-end test on tests/fixtures/repos/buildable-sample.
.PARAMETER Path
    Limit to specific test files or folders.
.PARAMETER MinimumCoverage
    Fail when module line coverage is below this percentage (CI only). Default 80.
#>
[CmdletBinding()]
param(
    [switch] $CI,
    [switch] $IncludeBuild,
    [string[]] $Path,
    [int] $MinimumCoverage = 80
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pester = Get-Module -ListAvailable Pester | Where-Object Version -ge ([version]'5.5.0') | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) { throw 'Pester 5.5+ is required: Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser' }
Import-Module $pester -Force

if ($IncludeBuild) { $env:SKR_INCLUDE_BUILD = '1' } else { $env:SKR_INCLUDE_BUILD = $null }

$config = New-PesterConfiguration
$config.Run.Path = if ($Path) { $Path } else { @((Join-Path $root 'tests' 'unit'), (Join-Path $root 'tests' 'integration')) }
$config.Run.PassThru = $true
$config.Output.Verbosity = if ($CI) { 'Normal' } else { 'Detailed' }
if ($CI) {
    $results = Join-Path $root 'tests' 'results'
    $null = New-Item -ItemType Directory -Force -Path $results
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = 'NUnitXml'
    $config.TestResult.OutputPath = Join-Path $results 'testResults.xml'
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @(Get-ChildItem (Join-Path $root 'tools' 'SpecKitRadzen') -Recurse -Filter '*.ps1' | ForEach-Object FullName)
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = Join-Path $results 'coverage.xml'
}
$run = Invoke-Pester -Configuration $config
if ($CI -and $run.CodeCoverage) {
    $pct = [math]::Round($run.CodeCoverage.CoveragePercent, 1)
    Write-Host "Module line coverage: $pct%"
    if ($pct -lt $MinimumCoverage) { throw "Coverage $pct% is below the minimum of $MinimumCoverage%." }
}
if ($run.FailedCount -gt 0) { throw "$($run.FailedCount) test(s) failed." }
Write-Host "Tests passed: $($run.PassedCount), skipped: $($run.SkippedCount)"
