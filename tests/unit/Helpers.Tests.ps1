BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
}

Describe 'Internal helpers' {
    It 'matches globs' {
        InModuleScope SpecKitRadzen {
            Test-SkrGlob -Path 'src/App/wwwroot/lib/x.js' -Pattern '**/wwwroot/lib/**' | Should -BeTrue
            Test-SkrGlob -Path 'a/b/Foo.razor' -Pattern '*.razor' | Should -BeTrue
            Test-SkrGlob -Path 'a/b/Foo.razor.cs' -Pattern '*.razor' | Should -BeFalse
            Test-SkrGlob -Path 'specs/001-x/a.md' -Pattern 'specs/**' | Should -BeTrue
            Test-SkrGlob -Path 'src/Migrations/1.cs' -Pattern '**/Migrations/**' | Should -BeTrue
        }
    }
    It 'recognises test paths' {
        InModuleScope SpecKitRadzen {
            Test-SkrTestPath 'tests/App.Tests/FooTests.cs' | Should -BeTrue
            Test-SkrTestPath 'src/App.UnitTests/Foo.cs' | Should -BeTrue
            Test-SkrTestPath 'src/App/Foo.cs' | Should -BeFalse
        }
    }
    It 'slugifies names' {
        InModuleScope SpecKitRadzen {
            ConvertTo-SkrSlug 'Klant Überzicht & Zoeken!' | Should -Be 'klant-uberzicht-zoeken'
            { ConvertTo-SkrSlug '!!!' } | Should -Throw
        }
    }
    It 'merges, replaces and removes managed blocks idempotently' {
        InModuleScope SpecKitRadzen {
            $a = Merge-SkrManagedBlock -Existing "# Title`n" -Body 'one' -TargetRelative 'AGENTS.md' -Version '2.0.0'
            $b = Merge-SkrManagedBlock -Existing $a -Body 'two' -TargetRelative 'AGENTS.md' -Version '2.1.0'
            ([regex]::Matches($b, 'speckit-radzen:begin')).Count | Should -Be 1
            $b | Should -Match 'two'
            $b | Should -Not -Match 'one'
            Merge-SkrManagedBlock -Existing $b -Body $null -TargetRelative 'AGENTS.md' | Should -Be "# Title`n"
            (Merge-SkrManagedBlock -Existing $null -Body 'x' -TargetRelative '.gitignore') | Should -Match '^# speckit-radzen:begin'
        }
    }
    It 'maps dot-folders to target paths' {
        InModuleScope SpecKitRadzen {
            ConvertTo-SkrTargetPath 'dot-github/prompts/a.prompt.md' | Should -Be '.github/prompts/a.prompt.md'
            ConvertTo-SkrTargetPath 'SPECKIT-RADZEN.md' | Should -Be 'SPECKIT-RADZEN.md'
        }
    }
    It 'distinguishes secret references, placeholders and literals' {
        InModuleScope SpecKitRadzen {
            Test-SkrSecretReference '${RADZEN_MCP_KEY}' | Should -BeTrue
            Test-SkrSecretReference '${input:radzen-key}' | Should -BeTrue
            Test-SkrSecretReference 'abc123' | Should -BeFalse
            Test-SkrPlaceholderValue 'YOUR-LICENSE-KEY' | Should -BeTrue
            Test-SkrPlaceholderValue '<key>' | Should -BeTrue
            Test-SkrPlaceholderValue 'rk_1234567890' | Should -BeFalse
        }
    }
    It 'parses markdown sections and tables' {
        InModuleScope SpecKitRadzen {
            $md = "# T`n## A`n| X | Y |`n|---|---|`n| 1 | 2 \| 3 |`n## B`ntext"
            $rows = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $md -Title 'A'))
            $rows.Count | Should -Be 1
            $rows[0]['X'] | Should -Be '1'
            (Get-SkrMarkdownSection -Markdown $md -Title 'B').Trim() | Should -Be 'text'
            Get-SkrMarkdownSection -Markdown $md -Title 'Missing' | Should -BeNullOrEmpty
        }
    }
    It 'hashes content independent of line endings' {
        InModuleScope SpecKitRadzen {
            $a = New-TemporaryFile; $b = New-TemporaryFile
            [IO.File]::WriteAllText($a, "x`r`ny`r`n"); [IO.File]::WriteAllText($b, "x`ny`n")
            Get-SkrContentHash $a | Should -Be (Get-SkrContentHash $b)
            Remove-Item $a, $b
        }
    }
    It 'merges MCP JSON without touching other servers and never overwrites user entries' {
        InModuleScope SpecKitRadzen {
            $tpl = Get-Content (Join-Path (Get-SkrKitRoot) 'mcp/templates/vscode.mcp.json') -Raw
            $merged = Merge-SkrMcpJson -Existing '{ "servers": { "a": { "url": "x" } } }' -TemplateText $tpl -RootKey servers | ConvertFrom-Json -AsHashtable
            $merged.servers.Keys | Sort-Object | Should -Be @('a', 'radzen-blazor')
            $merged.inputs[0].id | Should -Be 'radzen-key'
            Merge-SkrMcpJson -Existing ($merged | ConvertTo-Json -Depth 10) -TemplateText $tpl -RootKey servers | Should -BeNullOrEmpty
            $removed = Merge-SkrMcpJson -Existing ($merged | ConvertTo-Json -Depth 10) -TemplateText '' -RootKey servers -Remove | ConvertFrom-Json -AsHashtable
            $removed.servers.Keys | Should -Be @('a')
            $removed.Contains('inputs') | Should -BeFalse
            $literal = '{ "servers": { "radzen-blazor": { "url": "u", "headers": { "X-Radzen-Key": "literal-key-value" } } } }'
            Merge-SkrMcpJson -Existing $literal -TemplateText '' -RootKey servers -Remove | Should -BeNullOrEmpty
        }
    }
    It 'computes a code fingerprint that ignores specs and kit state' {
        $repo = New-EmptyRepository -Git
        try {
            InModuleScope SpecKitRadzen -Parameters @{ Repo = $repo } {
                param($Repo)
                $a = Get-SkrCodeFingerprint -Repository $Repo
                New-Item -ItemType Directory (Join-Path $Repo 'specs/001-x') -Force | Out-Null
                Set-Content (Join-Path $Repo 'specs/001-x/spec.md') 'x'
                Get-SkrCodeFingerprint -Repository $Repo | Should -Be $a
                Set-Content (Join-Path $Repo 'App.cs') 'class A {}'
                Get-SkrCodeFingerprint -Repository $Repo | Should -Not -Be $a
            }
        }
        finally { Remove-TestRepository $repo }
    }
}

Describe 'Repository build scripts' {
    It 'generated adapters and catalog have no drift' {
        & pwsh -NoProfile -File (Join-Path (Get-KitRoot) 'build/Test-Drift.ps1') | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
    It 'every public function has comment-based help' {
        foreach ($cmd in Get-Command -Module SpecKitRadzen) {
            (Get-Help $cmd.Name).Synopsis | Should -Not -Match '^\s*$' -Because $cmd.Name
        }
    }
    It 'module exports the documented functions' {
        $names = @(Get-Command -Module SpecKitRadzen | ForEach-Object Name)
        foreach ($n in 'Get-SkrProjectProfile', 'Invoke-SkrQualityGate', 'Invoke-SkrAntiPatternScan', 'Install-SpecKitRadzen', 'Update-SpecKitRadzen', 'Uninstall-SpecKitRadzen', 'Test-SpecKitRadzenInstall', 'Add-SkrMcpEvidence', 'Test-SkrMcpConfiguration', 'New-SkrFeature', 'Set-SkrFeaturePhase', 'Get-SkrFeatureState', 'Test-SkrArtifact', 'Invoke-SkrAnalysis', 'New-SkrBuildBaseline') {
            $names | Should -Contain $n
        }
    }
}

Describe 'Hash normalisation' {
    It 'ignores BOM and trailing newline differences' {
        InModuleScope SpecKitRadzen {
            $a = New-TemporaryFile; $b = New-TemporaryFile
            [IO.File]::WriteAllText($a, "x`r`ny", [Text.UTF8Encoding]::new($true))
            [IO.File]::WriteAllText($b, "x`ny`n`n")
            Get-SkrContentHash $a | Should -Be (Get-SkrContentHash $b)
            Remove-Item $a, $b
        }
    }
}
