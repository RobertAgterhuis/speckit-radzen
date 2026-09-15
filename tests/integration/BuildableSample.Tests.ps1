# End-to-end run of the worked example against tests/fixtures/repos/buildable-sample.
# Requires the .NET 10 SDK and NuGet access. Enabled with: build/Invoke-Tests.ps1 -IncludeBuild (or $env:SKR_INCLUDE_BUILD = '1').

BeforeDiscovery {
    $script:Enabled = ($env:SKR_INCLUDE_BUILD -eq '1') -and [bool](Get-Command dotnet -ErrorAction Ignore)
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
}

Describe 'Worked example on buildable-sample' -Tag 'Build' -Skip:(-not $script:Enabled) {
    BeforeAll {
        $repo = Copy-Fixture -Name 'buildable-sample'
        Set-Content (Join-Path $repo '.gitignore') "bin/`nobj/`n.speckit/radzen/tmp/"
        Initialize-GitRepository -Path $repo
        $restore = & dotnet restore (Join-Path $repo 'BuildableSample.slnx') 2>&1
        if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed: $($restore -join "`n")" }
        $profile0 = Get-SkrProjectProfile -Repository $repo
        $baseline = New-SkrBuildBaseline -Repository $repo
        $feature = New-SkrFeature -Name 'Customer search' -Repository $repo
        $example = Join-Path (Get-KitRoot) 'core/examples/specs/001-customer-search'
        foreach ($file in Get-ChildItem $example -File | Where-Object Name -ne 'state.json') { Copy-Item $file.FullName $feature.Path -Force }
        & git -C $repo add -A; & git -C $repo commit -q -m 'feature artifacts'
        $null = Set-SkrFeaturePhase -Feature 001 -McpAvailability available -Repository $repo
    }
    AfterAll { Remove-TestRepository $repo }

    It 'detects the sample correctly' {
        $profile0.radzen.serviceRegistration.value | Should -Be 'AddRadzenComponents'
        $profile0.blazor.globalRenderMode.value | Should -Be 'InteractiveServer'
        $profile0.testing.framework.value | Should -Contain 'xUnit'
        @($profile0.health | Where-Object severity -in 'blocker', 'major').Count | Should -Be 0
    }

    It 'has a green baseline with tests' {
        $baseline.BuildSucceeded | Should -BeTrue
        $baseline.Tests | Should -BeGreaterThan 0
        $baseline.FailingTests | Should -Be 0
    }

    It 'passes G0 to G4' {
        (Invoke-SkrQualityGate G0 -Feature 001 -Repository $repo).status | Should -Be 'pass'
        foreach ($step in @(@('discover', 'G1'), @('specify', $null), @('clarify', 'G2'), @('plan', 'G3'), @('tasks', $null), @('analyze', 'G4'))) {
            $null = Set-SkrFeaturePhase -Feature 001 -Phase $step[0] -Repository $repo
            if ($step[1]) {
                $r = Invoke-SkrQualityGate $step[1] -Feature 001 -Repository $repo
                $r.status | Should -Be 'pass' -Because "$($step[1]): $(($r.checks | Where-Object status -ne 'pass' | ForEach-Object { "$($_.check) $($_.message) $($_.evidence -join '; ')" }) -join ' | ')"
            }
        }
        $null = Set-SkrFeaturePhase -Feature 001 -Phase implement -Repository $repo
    }

    It 'implements both slices with G5 (build + tests) and G6' {
        Copy-Item (Join-Path (Get-KitRoot) 'tests/fixtures/overlays/001-customer-search/src') $repo -Recurse -Force
        Copy-Item (Join-Path (Get-KitRoot) 'tests/fixtures/overlays/001-customer-search/tests') $repo -Recurse -Force
        foreach ($s in 'S-01', 'S-02') {
            $g5 = Invoke-SkrQualityGate G5 -Feature 001 -Slice $s -Repository $repo
            $g5.status | Should -Be 'pass' -Because (($g5.checks | ForEach-Object { "$($_.check)=$($_.status) $($_.message) $($_.evidence -join '; ')" }) -join ' | ')
            ($g5.checks | Where-Object check -eq 'tests').message | Should -Match 'passed'
            $g6 = Invoke-SkrQualityGate G6 -Feature 001 -Slice $s -Repository $repo
            $g6.status | Should -BeIn @('pass', 'waived') -Because (($g6.checks | ForEach-Object { "$($_.message) $($_.evidence -join '; ')" }) -join ' | ')
            $null = Set-SkrFeaturePhase -Feature 001 -CompleteSlice $s -Repository $repo
        }
        $evidence = Get-Content (Join-Path $feature.Path 'mcp-evidence.json') -Raw | ConvertFrom-Json
        @($evidence.entries | Where-Object { -not $_.compileVerified }).Count | Should -Be 0
    }

    It 'passes review and done' {
        $null = Set-SkrFeaturePhase -Feature 001 -Phase review -Repository $repo
        $g7 = Invoke-SkrQualityGate G7 -Feature 001 -Repository $repo
        $g7.status | Should -Be 'pass' -Because (($g7.checks | ForEach-Object { "$($_.check)=$($_.status) $($_.message)" }) -join ' | ')
        $g8 = Invoke-SkrQualityGate G8 -Feature 001 -Repository $repo
        $g8.status | Should -Be 'pass' -Because (($g8.checks | ForEach-Object { "$($_.check)=$($_.status) $($_.message)" }) -join ' | ')
        (Get-SkrFeatureState -Feature 001 -Repository $repo).Phase | Should -Be 'done'
    }
}
