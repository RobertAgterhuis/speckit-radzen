BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
    function Write-RepoFile([string] $Repo, [string] $Rel, [string] $Content) {
        $p = Join-Path $Repo $Rel
        New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
        Set-Content -Path $p -Value $Content
    }
}

Describe 'MCP configuration check' {
    BeforeEach { $repo = New-EmptyRepository -Git }
    AfterEach { Remove-TestRepository $repo }

    It 'reports not-configured for an empty repository' {
        (Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel).Status | Should -Be 'not-configured'
    }

    It 'accepts every shipped template as secret-free' {
        $map = @{ 'claude-code.mcp.json' = '.mcp.json'; 'vscode.mcp.json' = '.vscode/mcp.json'; 'cursor.mcp.json' = '.cursor/mcp.json'; 'codex.config.toml' = '.codex/config.toml' }
        foreach ($k in $map.Keys) { Write-RepoFile $repo $map[$k] (Get-Content (Join-Path (Get-KitRoot) 'mcp/templates' $k) -Raw) }
        $r = Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel
        $r.Status | Should -Be 'configured'
        @($r.Servers).Count | Should -Be 4
        $r.Servers | ForEach-Object { $_.KeyKind | Should -Be 'reference' -Because $_.File }
    }

    It 'detects a literal key in a tracked JSON config' {
        Write-RepoFile $repo '.mcp.json' '{ "mcpServers": { "radzen-blazor": { "type": "http", "url": "https://app.radzen.com/mcp", "headers": { "X-Radzen-Key": "rk_live_1234567890abcdef" } } } }'
        $r = Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel
        $r.Status | Should -Be 'secret-in-repo'
        ($r | ConvertTo-Json -Depth 5) | Should -Not -Match 'rk_live_1234567890abcdef'
    }

    It 'detects a literal key in Codex http_headers' {
        Write-RepoFile $repo '.codex/config.toml' "[mcp_servers.radzen-blazor]`nurl = `"https://app.radzen.com/mcp`"`nhttp_headers = { `"X-Radzen-Key`" = `"abcdef1234567890`" }"
        (Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel).Status | Should -Be 'secret-in-repo'
    }

    It 'tolerates a literal key in a git-ignored local file' {
        Write-RepoFile $repo '.gitignore' '.vs/'
        Write-RepoFile $repo '.vs/mcp.json' '{ "servers": { "radzen-blazor": { "url": "https://app.radzen.com/mcp", "headers": { "X-Radzen-Key": "abcdef1234567890" } } } }'
        $r = Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel
        $r.Status | Should -Be 'configured'
        $r.Servers[0].GitIgnored | Should -BeTrue
    }

    It 'flags placeholders' {
        Write-RepoFile $repo '.cursor/mcp.json' '{ "mcpServers": { "radzen-blazor": { "url": "https://app.radzen.com/mcp", "headers": { "X-Radzen-Key": "YOUR-LICENSE-KEY" } } } }'
        $r = Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel
        $r.Servers[0].KeyKind | Should -Be 'placeholder'
        $r.Status | Should -Be 'configured'
    }

    It 'returns not-configured from probe when the key variable is absent' {
        $old = $env:RADZEN_MCP_KEY
        try {
            $env:RADZEN_MCP_KEY = $null
            (Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel -Probe).Probe.Status | Should -Be 'not-configured'
        }
        finally { $env:RADZEN_MCP_KEY = $old }
    }
}

Describe 'MCP evidence' {
    BeforeAll {
        $repo = New-EmptyRepository -Git
        $null = New-SkrFeature -Name 'Evidence' -Repository $repo
    }
    AfterAll { Remove-TestRepository $repo }

    It 'assigns sequential IDs, ranks and defaults' {
        $e = Add-SkrMcpEvidence -Repository $repo -Component RadzenDataGrid -Members LoadData, Count -Question 'Server paging?' -Query 'RadzenDataGrid LoadData Count' -Source mcp -Summary 'Use LoadData and Count.'
        $e.id | Should -Be 'MCP-001'
        $e.rank | Should -Be 3
        $e.server | Should -Be 'radzen-blazor'
        $e.tool | Should -Be 'search'
        Join-Path $repo 'specs/001-evidence/mcp-evidence.md' | Should -Exist
    }

    It 'returns existing evidence instead of duplicating it' {
        $e = Add-SkrMcpEvidence -Repository $repo -Component RadzenDataGrid -Members Count, LoadData -Question 'again' -Query 'again' -Source mcp -Summary 'dup' -WarningAction SilentlyContinue
        $e.id | Should -Be 'MCP-001'
    }

    It 'supersedes entries and marks compiler evidence as compile-verified' {
        $e = Add-SkrMcpEvidence -Repository $repo -Component RadzenDataGrid -Members Count -Question 'compile' -Source compiler -Summary 'Count exists in 7.1.2' -Supersedes MCP-001
        $e.compileVerified | Should -BeTrue
        $doc = Get-Content (Join-Path $repo 'specs/001-evidence/mcp-evidence.json') -Raw | ConvertFrom-Json
        ($doc.entries | Where-Object id -eq 'MCP-001').status | Should -Be 'superseded'
    }

    It 'validates required inputs' {
        { Add-SkrMcpEvidence -Repository $repo -Component X -Question q -Source mcp -Summary s } | Should -Throw '*-Query is required*'
        { Add-SkrMcpEvidence -Repository $repo -Component X -Question q -Source project -Summary s } | Should -Throw '*ProjectEvidence*'
        { Add-SkrMcpEvidence -Repository $repo -Component X -Question q -Source docs -Summary s -FallbackApproved } | Should -Throw '*FallbackReason*'
        { Add-SkrMcpEvidence -Repository $repo -Component X -Question q -Query 'X-Radzen-Key: abcdefghijkl' -Source mcp -Summary s } | Should -Throw '*licence key*'
    }
}
