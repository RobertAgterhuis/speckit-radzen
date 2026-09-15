BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
    $script:HasDotnet = [bool](Get-Command dotnet -ErrorAction Ignore)

    function New-OfflineRepo {
        $repo = New-EmptyRepository
        Set-Content (Join-Path $repo 'global.json') '{ "sdk": { "version": "10.0.100", "rollForward": "latestMajor" } }'
        Set-Content (Join-Path $repo 'App.slnx') '<Solution><Project Path="src/App/App.csproj" /></Solution>'
        New-Item -ItemType Directory -Force (Join-Path $repo 'src/App') | Out-Null
        Set-Content (Join-Path $repo 'src/App/App.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><Nullable>enable</Nullable></PropertyGroup></Project>'
        Set-Content (Join-Path $repo 'src/App/Customer.cs') 'namespace App; public sealed record Customer(int Id, string Name);'
        Set-Content (Join-Path $repo '.gitignore') "bin/`nobj/`n.speckit/radzen/tmp/"
        New-Item -ItemType Directory -Force (Join-Path $repo '.speckit/radzen') | Out-Null
        Set-Content (Join-Path $repo '.speckit/radzen/config.json') '{ "gates": { "G5": { "runTests": false, "timeoutMinutes": 10 } } }'
        Initialize-GitRepository -Path $repo
        return $repo
    }
    function Commit([string] $repo, [string] $msg) { & git -C $repo add -A; & git -C $repo commit -q -m $msg }
}

Describe 'Quality gates end-to-end (offline build)' -Skip:(-not (Get-Command dotnet -ErrorAction Ignore)) {
    BeforeAll {
        $repo = New-OfflineRepo
        $null = Get-SkrProjectProfile -Repository $repo
        $baseline = New-SkrBuildBaseline -Repository $repo
        $feature = New-SkrFeature -Name 'Customer search' -Repository $repo
        foreach ($file in Get-ChildItem (Join-Path (Get-KitRoot) 'core/examples/specs/001-customer-search') -File -Filter '*.md') {
            Copy-Item $file.FullName (Join-Path $feature.Path $file.Name) -Force
        }
        Copy-Item (Join-Path (Get-KitRoot) 'core/examples/specs/001-customer-search/mcp-evidence.json') $feature.Path -Force
        $doc = Get-Content (Join-Path $feature.Path 'mcp-evidence.json') -Raw | ConvertFrom-Json
        foreach ($e in $doc.entries) { $e.compileVerified = $false }
        $doc | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $feature.Path 'mcp-evidence.json')
        # tasks start unticked
        (Get-Content (Join-Path $feature.Path 'tasks.md') -Raw) -replace '- \[x\]', '- [ ]' | Set-Content (Join-Path $feature.Path 'tasks.md')
        Commit $repo 'feature scaffold'
    }
    AfterAll { Remove-TestRepository $repo }

    It 'captured a green baseline' {
        $baseline.BuildSucceeded | Should -BeTrue
        Join-Path $repo '.speckit/radzen/baseline/build-baseline.json' | Should -Exist
    }

    It 'G0 fails until MCP availability is recorded' {
        $r = Invoke-SkrQualityGate G0 -Feature 001 -Repository $repo
        $r.status | Should -Be 'fail'
        ($r.checks | Where-Object check -eq 'mcp-availability-recorded').status | Should -Be 'fail'
        $null = Set-SkrFeaturePhase -Feature 001 -McpAvailability available -Repository $repo
        $r = Invoke-SkrQualityGate G0 -Feature 001 -Repository $repo
        $r.status | Should -Be 'pass'
        $r.exitCode | Should -Be 0
        Join-Path $feature.Path 'gates/dependencies.json' | Should -Exist
        (Get-Content (Join-Path $feature.Path 'state.json') -Raw | ConvertFrom-Json).baseRef | Should -Not -BeNullOrEmpty
    }

    It 'passes G1–G4 on the worked example and moves through the phases' {
        $null = Set-SkrFeaturePhase -Feature 001 -Phase discover -Repository $repo
        (Invoke-SkrQualityGate G1 -Feature 001 -Repository $repo).status | Should -Be 'pass'
        $null = Set-SkrFeaturePhase -Feature 001 -Phase specify -Repository $repo
        $null = Set-SkrFeaturePhase -Feature 001 -Phase clarify -Repository $repo
        (Invoke-SkrQualityGate G2 -Feature 001 -Repository $repo).status | Should -Be 'pass'
        $null = Set-SkrFeaturePhase -Feature 001 -Phase plan -Repository $repo
        (Invoke-SkrQualityGate G3 -Feature 001 -Repository $repo).status | Should -Be 'pass'
        $null = Set-SkrFeaturePhase -Feature 001 -Phase tasks -Repository $repo
        $null = Set-SkrFeaturePhase -Feature 001 -Phase analyze -Repository $repo
        (Invoke-SkrQualityGate G4 -Feature 001 -Repository $repo).status | Should -Be 'pass'
        $s = Set-SkrFeaturePhase -Feature 001 -Phase implement -Repository $repo
        @($s.Slices.Keys | Sort-Object) | Should -Be @('S-01', 'S-02')
    }

    It 'G3 fails when the profile becomes stale' {
        Add-Content (Join-Path $repo 'src/App/App.csproj') '<!-- touched -->'
        $r = Invoke-SkrQualityGate G3 -Feature 001 -Repository $repo
        ($r.checks | Where-Object check -eq 'profile-fresh').status | Should -Be 'fail'
        $null = Get-SkrProjectProfile -Repository $repo
        (Invoke-SkrQualityGate G3 -Feature 001 -Repository $repo).status | Should -Be 'pass'
    }

    It 'G5 fails on a new warning and passes when it is fixed; evidence gets compile-verified' {
        Set-Content (Join-Path $repo 'src/App/CustomerQuery.cs') 'namespace App; public static class CustomerQuery { public static int Skip(int? s) { string x = null; return s ?? 0; } }'
        $r = Invoke-SkrQualityGate G5 -Feature 001 -Slice S-01 -Repository $repo
        $r.status | Should -Be 'fail'
        ($r.checks | Where-Object check -eq 'new-warnings').status | Should -Be 'fail'
        { Set-SkrFeaturePhase -Feature 001 -CompleteSlice S-01 -Repository $repo } | Should -Throw '*G5 has not passed*'
        Set-Content (Join-Path $repo 'src/App/CustomerQuery.cs') 'namespace App; public static class CustomerQuery { public static int Skip(int? s) => s ?? 0; }'
        $r = Invoke-SkrQualityGate G5 -Feature 001 -Slice S-01 -Repository $repo
        $r.status | Should -Be 'waived' -Because 'tests are disabled in config, so G5 passes with a waiver'
        $r.exitCode | Should -Be 2
        ($r.checks | Where-Object check -eq 'build').status | Should -Be 'pass'
        ($r.checks | Where-Object check -eq 'evidence-compile-verified').message | Should -Match '^2 evidence'
        Join-Path $feature.Path 'gates/G5-S-01.json' | Should -Exist
    }

    It 'G5 fails with a build error' {
        Set-Content (Join-Path $repo 'src/App/Broken.cs') 'namespace App; public class Broken { void M() { int x = "no"; } }'
        $r = Invoke-SkrQualityGate G5 -Feature 001 -Slice S-01 -Repository $repo
        ($r.checks | Where-Object check -eq 'build').status | Should -Be 'fail'
        ($r.checks | Where-Object check -eq 'build').evidence -join ' ' | Should -Match 'CS0029'
        Remove-Item (Join-Path $repo 'src/App/Broken.cs')
        (Invoke-SkrQualityGate G5 -Feature 001 -Slice S-01 -Repository $repo).status | Should -BeIn @('pass', 'waived')
    }

    It 'G6 fails on a blocker/major finding and passes after the fix' {
        Set-Content (Join-Path $repo 'src/App/Loader.cs') 'namespace App; public class Loader { public async void Load() { await System.Threading.Tasks.Task.Delay(1); } }'
        $r = Invoke-SkrQualityGate G6 -Feature 001 -Slice S-01 -Repository $repo
        $r.status | Should -Be 'fail'
        $r.exitCode | Should -Be 1
        Set-Content (Join-Path $repo 'src/App/Loader.cs') 'namespace App; public class Loader { public async System.Threading.Tasks.Task Load() { await System.Threading.Tasks.Task.Delay(1); } }'
        (Invoke-SkrQualityGate G6 -Feature 001 -Slice S-01 -Repository $repo).status | Should -Be 'pass'
        Join-Path $feature.Path 'gates/scan.sarif' | Should -Exist
    }

    It 'completes both slices and enters review' {
        $null = Set-SkrFeaturePhase -Feature 001 -CompleteSlice S-01 -Repository $repo
        { Set-SkrFeaturePhase -Feature 001 -Phase review -Repository $repo } | Should -Throw '*S-02*'
        (Invoke-SkrQualityGate G5 -Feature 001 -Slice S-02 -Repository $repo).status | Should -BeIn @('pass', 'waived')
        (Invoke-SkrQualityGate G6 -Feature 001 -Slice S-02 -Repository $repo).status | Should -Be 'pass'
        $null = Set-SkrFeaturePhase -Feature 001 -CompleteSlice S-02 -Repository $repo
        (Set-SkrFeaturePhase -Feature 001 -Phase review -Repository $repo).Phase | Should -Be 'review'
    }

    It 'G7 detects unapproved dependency changes' {
        $csproj = Join-Path $repo 'src/App/App.csproj'
        $original = Get-Content $csproj -Raw
        Set-Content $csproj ($original -replace '</Project>', '<ItemGroup><PackageReference Include="Humanizer" Version="2.14.1" /></ItemGroup></Project>')
        $r = Invoke-SkrQualityGate G7 -Feature 001 -Repository $repo
        ($r.checks | Where-Object check -eq 'dependency-drift').status | Should -Be 'fail'
        ($r.checks | Where-Object check -eq 'dependency-drift').evidence | Should -Match 'Humanizer'
        Set-Content $csproj $original -NoNewline
        $r = Invoke-SkrQualityGate G7 -Feature 001 -Repository $repo
        $r.status | Should -Be 'pass' -Because (($r.checks | Where-Object status -ne 'pass' | ForEach-Object { "$($_.check): $($_.message) $($_.evidence -join '; ')" }) -join ' | ')
    }

    It 'G8 requires ticked tasks and unchanged code, then marks the feature done' {
        $r = Invoke-SkrQualityGate G8 -Feature 001 -Repository $repo
        ($r.checks | Where-Object check -eq 'tasks-complete').status | Should -Be 'fail'
        $tasks = Join-Path $feature.Path 'tasks.md'
        (Get-Content $tasks -Raw) -replace '- \[ \]', '- [x]' | Set-Content $tasks
        Add-Content (Join-Path $repo 'src/App/Customer.cs') '// late change'
        $r = Invoke-SkrQualityGate G8 -Feature 001 -Repository $repo
        ($r.checks | Where-Object check -eq 'code-unchanged-since-gates').status | Should -Be 'fail'
        foreach ($s in 'S-01', 'S-02') {
            $null = Invoke-SkrQualityGate G5 -Feature 001 -Slice $s -Repository $repo
            $null = Invoke-SkrQualityGate G6 -Feature 001 -Slice $s -Repository $repo
        }
        $null = Invoke-SkrQualityGate G7 -Feature 001 -Repository $repo
        $r = Invoke-SkrQualityGate G8 -Feature 001 -Repository $repo
        $r.status | Should -Be 'pass'
        (Get-SkrFeatureState -Feature 001 -Repository $repo).Phase | Should -Be 'done'
        $report = Get-Content (Join-Path $feature.Path 'gate-report.md') -Raw
        $report | Should -Match '\| G8 \| Done \| PASS'
        foreach ($g in 'G0', 'G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7', 'G8') {
            Test-Json -Path (Join-Path $feature.Path "gates/$g.json") -SchemaFile (Join-Path (Get-KitRoot) 'core/schemas/gate-result.schema.json') | Should -BeTrue
        }
    }

    It 'returns exit code 3 when the baseline is missing' {
        Remove-Item (Join-Path $repo '.speckit/radzen/baseline') -Recurse -Force
        $r = Invoke-SkrQualityGate G5 -Feature 001 -Slice S-01 -Repository $repo
        $r.exitCode | Should -Be 3
        $r.status | Should -Be 'error'
    }
}

Describe 'Build output and TRX parsing' {
    It 'parses warnings and errors and ignores line numbers in keys' {
        InModuleScope SpecKitRadzen {
            $out = @(
                '/repo/src/App/A.cs(10,5): warning CS8600: Converting null literal. [/repo/src/App/App.csproj]',
                '/repo/src/App/A.cs(12,5): warning CS8600: Converting null literal. [/repo/src/App/App.csproj]',
                'CSC : error CS5001: Program does not contain a static Main method [/repo/src/App/App.csproj]',
                'Build succeeded.'
            ) -join "`n"
            $p = ConvertFrom-SkrBuildOutput -Output $out -Repository '/repo'
            $p.Warnings.Count | Should -Be 1
            @($p.Warnings.Values)[0].file | Should -Be 'src/App/A.cs'
            $p.Errors.Count | Should -Be 1
        }
    }
    It 'reads TRX counters and failed test names' {
        InModuleScope SpecKitRadzen {
            $dir = Join-Path ([IO.Path]::GetTempPath()) ('trx-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory $dir | Out-Null
            Set-Content (Join-Path $dir 'r.trx') @'
<?xml version="1.0" encoding="utf-8"?>
<TestRun xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010">
  <Results>
    <UnitTestResult testName="Tests.A" outcome="Passed" />
    <UnitTestResult testName="Tests.B" outcome="Failed" />
  </Results>
  <ResultSummary outcome="Failed"><Counters total="3" executed="2" passed="1" failed="1" error="0" notExecuted="1" /></ResultSummary>
</TestRun>
'@
            $r = Read-SkrTrxResult -Directory $dir
            $r.Total | Should -Be 3
            $r.Failed | Should -Be 1
            $r.Skipped | Should -Be 1
            $r.FailedTests | Should -Be @('Tests.B')
            Remove-Item $dir -Recurse -Force
        }
    }
}
