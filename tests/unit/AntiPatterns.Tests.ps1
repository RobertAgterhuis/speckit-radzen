BeforeDiscovery {
    $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
    $fixtures = (Get-Content (Join-Path $root 'tests/fixtures/antipatterns/fixtures.json') -Raw | ConvertFrom-Json -AsHashtable).cases
    $script:FixtureCases = @($fixtures | ForEach-Object { @{ Rule = $_.rule; Positive = $_.positive; Negative = $_.negative } })
    $script:FixtureRuleIds = @($fixtures | ForEach-Object { $_.rule })
    $rules = (Get-Content (Join-Path $root 'core/antipatterns/rules.json') -Raw | ConvertFrom-Json).rules
    $script:AutomatedRules = @($rules | Where-Object { $_.detection -in 'regex', 'absence' } | ForEach-Object { @{ Rule = $_.id } })
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
    function Invoke-FixtureScan([hashtable] $Files) {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('skr-ap-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $null = New-Item -ItemType Directory -Path $tmp
        foreach ($name in $Files.Keys) { [IO.File]::WriteAllText((Join-Path $tmp $name), $Files[$name]) }
        Set-Content (Join-Path $tmp 'global.json') '{}'
        try { Invoke-SkrAntiPatternScan -Repository $tmp -All -NoWrite }
        finally { Remove-Item $tmp -Recurse -Force }
    }
}

Describe 'Anti-pattern catalog' {
    It 'is valid against its schema' {
        Test-Json -Path (Join-Path (Get-KitRoot) 'core/antipatterns/rules.json') -SchemaFile (Join-Path (Get-KitRoot) 'core/schemas/antipattern-rules.schema.json') | Should -BeTrue
    }
    It 'has at least 45 rules with unique IDs' {
        $rules = (Get-Content (Join-Path (Get-KitRoot) 'core/antipatterns/rules.json') -Raw | ConvertFrom-Json).rules
        $rules.Count | Should -BeGreaterOrEqual 45
        @($rules.id | Group-Object | Where-Object Count -gt 1).Count | Should -Be 0
    }
    It 'references only existing constitution principles' {
        $rules = (Get-Content (Join-Path (Get-KitRoot) 'core/antipatterns/rules.json') -Raw | ConvertFrom-Json).rules
        $constitution = Get-Content (Join-Path (Get-KitRoot) 'core/constitution/constitution.md') -Raw
        foreach ($p in ($rules.principles | Select-Object -Unique)) { $constitution | Should -Match "## $p " }
    }
    It 'has a positive and a negative fixture for rule <Rule>' -ForEach $script:AutomatedRules {
        $cases = (Get-Content (Join-Path (Get-KitRoot) 'tests/fixtures/antipatterns/fixtures.json') -Raw | ConvertFrom-Json -AsHashtable).cases
        $case = $cases | Where-Object { $_.rule -eq $Rule }
        $case | Should -Not -BeNullOrEmpty
        $case.positive.Count | Should -BeGreaterThan 0
        $case.negative.Count | Should -BeGreaterThan 0
    }
}

Describe 'Scanner fixtures' {
    It '<Rule>: positive fixture is reported' -ForEach $script:FixtureCases {
        $res = Invoke-FixtureScan $Positive
        @($res.findings | Where-Object { $_.rule -eq $Rule -and -not $_.waived }).Count | Should -BeGreaterThan 0
    }
    It '<Rule>: negative fixture is clean' -ForEach $script:FixtureCases {
        $res = Invoke-FixtureScan $Negative
        @($res.findings | Where-Object { $_.rule -eq $Rule -and -not $_.waived }).Count | Should -Be 0
    }
}

Describe 'Scanner behaviour' {
    BeforeEach { $repo = New-EmptyRepository -Git }
    AfterEach { Remove-TestRepository $repo }

    It 'honours inline waivers with a reason and reports them as waived' {
        Set-Content (Join-Path $repo 'Page.razor') "@* speckit-radzen:ignore AP-RDZ-02 reason=`"five fixed statuses`" *@`n<RadzenDataGrid TItem=`"S`" Data=`"@items`" />"
        $res = Invoke-SkrAntiPatternScan -Repository $repo -All -NoWrite
        $f = $res.findings | Where-Object rule -eq 'AP-RDZ-02'
        $f.waived | Should -BeTrue
        $f.waiver | Should -Be 'five fixed statuses'
        $res.summary.waived | Should -Be 1
    }

    It 'honours file-level and config waivers' {
        Set-Content (Join-Path $repo 'A.razor') "@* speckit-radzen:ignore-file AP-RND-04 reason=`"legacy page, tracked in #12`" *@`n@code { async void A() {} async void B() {} }"
        Set-Content (Join-Path $repo 'B.razor') '@code { async void C() {} }'
        New-Item -ItemType Directory -Force (Join-Path $repo '.speckit/radzen') | Out-Null
        Set-Content (Join-Path $repo '.speckit/radzen/config.json') '{ "scan": { "waivers": [ { "rule": "AP-RND-04", "path": "B.razor", "reason": "approved by lead" } ] } }'
        $res = Invoke-SkrAntiPatternScan -Repository $repo -All -NoWrite
        @($res.findings | Where-Object { $_.rule -eq 'AP-RND-04' -and -not $_.waived }).Count | Should -Be 0
        @($res.findings | Where-Object { $_.rule -eq 'AP-RND-04' -and $_.waived }).Count | Should -Be 3
    }

    It 'scans only changed files by default' {
        Set-Content (Join-Path $repo 'Old.razor') '@code { async void Old() {} }'
        & git -C $repo add -A; & git -C $repo commit -q -m old
        Set-Content (Join-Path $repo 'New.razor') '@code { async void New() {} }'
        $res = Invoke-SkrAntiPatternScan -Repository $repo -NoWrite
        @($res.findings.file) | Should -Be @('New.razor')
        $res.scope | Should -Match 'changed since'
    }

    It 'scans changed files since the feature base commit' {
        $f = New-SkrFeature -Name 'Scan' -Repository $repo
        Set-Content (Join-Path $repo 'One.razor') '@code { async void One() {} }'
        & git -C $repo add -A; & git -C $repo commit -q -m one
        Set-Content (Join-Path $repo 'Two.razor') '@code { async void Two() {} }'
        $res = Invoke-SkrAntiPatternScan -Repository $repo -Feature $f.Number
        @($res.findings.file | Sort-Object) | Should -Be @('One.razor', 'Two.razor')
        Join-Path $f.Path 'gates/scan.md' | Should -Exist
        $sarif = Get-Content (Join-Path $f.Path 'gates/scan.sarif') -Raw | ConvertFrom-Json
        $sarif.version | Should -Be '2.1.0'
        $sarif.runs[0].results.Count | Should -Be 2
    }

    It 'reports deleted test files' {
        New-Item -ItemType Directory (Join-Path $repo 'tests') | Out-Null
        Set-Content (Join-Path $repo 'tests/CustomerTests.cs') 'public class CustomerTests {}'
        & git -C $repo add -A; & git -C $repo commit -q -m tests
        Remove-Item (Join-Path $repo 'tests/CustomerTests.cs')
        $res = Invoke-SkrAntiPatternScan -Repository $repo -NoWrite
        ($res.findings | Where-Object rule -eq 'AP-TST-03').file | Should -Be 'tests/CustomerTests.cs'
    }

    It 'maps project health to tool rules' {
        Copy-Item (Join-Path (Get-KitRoot) 'tests/fixtures/repos/brownfield-mixed/*') $repo -Recurse -Force
        $null = Get-SkrProjectProfile -Repository $repo
        $res = Invoke-SkrAntiPatternScan -Repository $repo -All -NoWrite
        $ids = @($res.findings.rule)
        $ids | Should -Contain 'AP-RDZ-06'
        $ids | Should -Contain 'AP-RDZ-05'
        $ids | Should -Contain 'AP-RND-01'
        $ids | Should -Contain 'AP-RND-04'
    }

    It 'applies local rules, disabled rules and severity overrides' {
        New-Item -ItemType Directory -Force (Join-Path $repo '.speckit/radzen/local') | Out-Null
        Set-Content (Join-Path $repo '.speckit/radzen/local/antipatterns.local.json') (@{
                schemaVersion = 1
                rules         = @(@{ id = 'AP-LOC-01'; title = 'No Console.WriteLine'; severity = 'major'; category = 'LOC'; detection = 'regex'; files = @('*.cs'); pattern = 'Console\.WriteLine'; principles = @('P-02'); doc = 'local'; why = 'Use ILogger.'; fix = 'Inject ILogger.' })
            } | ConvertTo-Json -Depth 5)
        Set-Content (Join-Path $repo '.speckit/radzen/config.json') '{ "scan": { "disabledRules": ["AP-RND-04"], "severityOverrides": { "AP-FRM-04": "minor" } } }'
        Set-Content (Join-Path $repo 'X.cs') "class X { async void A() {} void B() { Console.WriteLine(1); try {} catch {} } }"
        $res = Invoke-SkrAntiPatternScan -Repository $repo -All -NoWrite
        @($res.findings.rule) | Should -Contain 'AP-LOC-01'
        @($res.findings.rule) | Should -Not -Contain 'AP-RND-04'
        ($res.findings | Where-Object rule -eq 'AP-FRM-04').severity | Should -Be 'minor'
    }

    It 'lists manual-review rules' {
        $manual = Invoke-SkrAntiPatternScan -Repository $repo -ListManual
        @($manual.id) | Should -Contain 'AP-SEC-01'
        @($manual).Count | Should -BeGreaterThan 10
    }

    It 'excludes specs, kit state and configured paths' {
        New-Item -ItemType Directory -Force (Join-Path $repo 'specs/001-x'), (Join-Path $repo 'wwwroot/lib') | Out-Null
        Set-Content (Join-Path $repo 'specs/001-x/Bad.razor') '@code { async void A() {} }'
        Set-Content (Join-Path $repo 'wwwroot/lib/x.cs') 'class X { async void A() {} }'
        $res = Invoke-SkrAntiPatternScan -Repository $repo -All -NoWrite
        @($res.findings).Count | Should -Be 0
    }
}
