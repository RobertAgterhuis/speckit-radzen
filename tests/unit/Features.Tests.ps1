BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
}

Describe 'Feature lifecycle' {
    BeforeEach { $repo = New-EmptyRepository -Git }
    AfterEach { Remove-TestRepository $repo }

    It 'creates numbered feature folders with templates and valid state' {
        $a = New-SkrFeature -Name 'Customer search' -Repository $repo
        $b = New-SkrFeature -Name 'Order Überblick!' -Repository $repo
        $a.Id | Should -Be '001-customer-search'
        $b.Id | Should -Be '002-order-uberblick'
        foreach ($f in 'spec.md', 'plan.md', 'tasks.md', 'discovery.md', 'test-scenarios.md', 'review.md', 'state.json', 'mcp-evidence.json') {
            Join-Path $a.Path $f | Should -Exist
        }
        (Get-Content (Join-Path $a.Path 'spec.md') -Raw) | Should -Match 'Feature Specification: Customer search'
        $state = Get-Content (Join-Path $a.Path 'state.json') -Raw
        Test-Json -Json $state -SchemaFile (Join-Path (Get-KitRoot) 'core/schemas/state.schema.json') | Should -BeTrue
    }

    It 'refuses duplicate names' {
        $null = New-SkrFeature -Name 'Same' -Repository $repo
        { New-SkrFeature -Name 'same' -Repository $repo } | Should -Throw '*already exists*'
    }

    It 'resolves features by number, slug and default' {
        $null = New-SkrFeature -Name 'One' -Repository $repo
        $null = New-SkrFeature -Name 'Two' -Repository $repo
        (Get-SkrFeatureState -Feature '001' -Repository $repo).Feature | Should -Be '001-one'
        (Get-SkrFeatureState -Feature 'two' -Repository $repo).Feature | Should -Be '002-two'
        (Get-SkrFeatureState -Repository $repo).Feature | Should -Be '002-two'
        { Get-SkrFeatureState -Feature '009' -Repository $repo } | Should -Throw '*not found*'
    }

    It 'enforces entry gates and forbids skipping phases' {
        $null = New-SkrFeature -Name 'Gated' -Repository $repo
        { Set-SkrFeaturePhase -Phase discover -Repository $repo } | Should -Throw '*gate G0 has not passed*'
        { Set-SkrFeaturePhase -Phase plan -Repository $repo } | Should -Throw '*Cannot skip*'
        (Set-SkrFeaturePhase -Phase discover -Force -Note 'test' -Repository $repo).Phase | Should -Be 'discover'
        $state = Get-Content (Join-Path $repo 'specs/001-gated/state.json') -Raw | ConvertFrom-Json
        $state.history[-1].event | Should -Match 'forced'
    }

    It 'records MCP availability' {
        $null = New-SkrFeature -Name 'Mcp' -Repository $repo
        (Set-SkrFeaturePhase -McpAvailability quota-exhausted -Note 'trial' -Repository $repo).Mcp | Should -Be 'quota-exhausted'
    }

    It 'does not complete a slice before G5 and G6 passed' {
        $null = New-SkrFeature -Name 'Slices' -Repository $repo
        $null = Set-SkrFeaturePhase -Phase implement -Force -Repository $repo
        { Set-SkrFeaturePhase -CompleteSlice S-01 -Repository $repo } | Should -Throw '*G5 has not passed*'
    }

    It 'lints an unfilled template with placeholder and structure errors' {
        $null = New-SkrFeature -Name 'Lint' -Repository $repo
        $findings = @(Test-SkrArtifact -Repository $repo)
        @($findings | Where-Object rule -eq 'placeholder').Count | Should -BeGreaterThan 5
        @($findings | Where-Object { $_.artifact -eq 'plan' -and $_.rule -eq 'constitution' }).Count | Should -Be 16
    }
}

Describe 'Artifact lint and analysis on the worked example' {
    BeforeAll {
        $repo = New-EmptyRepository -Git
        $specs = Join-Path $repo 'specs'
        Copy-Item -Path (Join-Path (Get-KitRoot) 'core/examples/specs') -Destination $repo -Recurse
    }
    AfterAll { Remove-TestRepository $repo }

    It 'lints clean in strict mode' {
        $errors = @(Test-SkrArtifact -Feature 001 -Strict -Repository $repo | Where-Object severity -eq 'error')
        $errors | ForEach-Object { "$($_.artifact): $($_.message)" } | Should -BeNullOrEmpty
    }

    It 'has a complete traceability matrix' {
        $errors = @(Invoke-SkrAnalysis -Feature 001 -Repository $repo | Where-Object severity -eq 'error')
        $errors | ForEach-Object message | Should -BeNullOrEmpty
        Get-Content (Join-Path $repo 'specs/001-customer-search/analysis.md') -Raw | Should -Match '\| FR-001 \|'
    }

    It 'detects an FR without acceptance criterion' {
        $spec = Join-Path $repo 'specs/001-customer-search/spec.md'
        $original = Get-Content $spec -Raw
        try {
            Set-Content -Path $spec -Value ($original -replace '(## Functional requirements\s*\n)', "`$1`n- **FR-099** — Orphan requirement.`n")
            @(Test-SkrArtifact -Feature 001 -Artifact spec -Repository $repo | Where-Object { $_.message -like 'FR-099 has no acceptance criterion*' }).Count | Should -Be 1
            @(Invoke-SkrAnalysis -Feature 001 -NoWrite -Repository $repo | Where-Object rule -eq 'fr-without-task').Count | Should -BeGreaterThan 0
        }
        finally { Set-Content -Path $spec -Value $original -NoNewline }
    }

    It 'detects references to missing evidence' {
        $plan = Join-Path $repo 'specs/001-customer-search/plan.md'
        $original = Get-Content $plan -Raw
        try {
            Set-Content -Path $plan -Value ($original + "`nSee MCP-099.`n")
            @(Invoke-SkrAnalysis -Feature 001 -NoWrite -Repository $repo | Where-Object rule -eq 'missing-evidence').Count | Should -Be 1
        }
        finally { Set-Content -Path $plan -Value $original -NoNewline }
    }

    It 'rejects weak evidence unless an approved fallback is recorded' {
        $null = Add-SkrMcpEvidence -Feature 001 -Component RadzenChart -Members Series -Question 'q' -Source model -Summary 'guess' -Repository $repo -WarningAction SilentlyContinue
        @(Invoke-SkrAnalysis -Feature 001 -NoWrite -Repository $repo | Where-Object rule -eq 'weak-evidence').Count | Should -Be 1
    }
}
