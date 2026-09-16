BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
    function New-DistCopy {
        # A disposable copy of the distribution, so tests can simulate a newer version.
        $dist = Join-Path ([IO.Path]::GetTempPath()) ('skr-dist-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory $dist | Out-Null
        foreach ($d in 'core', 'tools', 'integrations', 'mcp', 'install') { Copy-Item (Join-Path (Get-KitRoot) $d) $dist -Recurse }
        Copy-Item (Join-Path (Get-KitRoot) 'VERSION') $dist
        return $dist
    }
    function Read-Manifest([string] $repo) { Get-Content (Join-Path $repo '.speckit/radzen/install-manifest.json') -Raw | ConvertFrom-Json -AsHashtable }
}

Describe 'Installer lifecycle' {
    BeforeEach { $repo = New-EmptyRepository -Git }
    AfterEach { Remove-TestRepository $repo; $env:SKR_INSTALL_FAIL_AFTER = $null }

    It 'installs kit, adapters and a valid manifest' {
        $r = Install-SpecKitRadzen -Repository $repo -Agents claude, copilot, codex, cursor, generic -Yes
        $r.Applied | Should -BeTrue
        foreach ($p in '.speckit/radzen/core/constitution/constitution.md', '.speckit/radzen/tools/speckit-radzen.ps1', '.speckit/radzen/tools/SpecKitRadzen/SpecKitRadzen.psd1',
            '.claude/skills/speckit-radzen/SKILL.md', '.claude/commands/speckit-radzen.plan.md', '.claude/agents/speckit-radzen-reviewer.md',
            '.github/instructions/speckit-radzen-razor.instructions.md', '.github/prompts/speckit-radzen.implement.prompt.md', '.github/skills/speckit-radzen/SKILL.md',
            '.agents/skills/speckit-radzen/SKILL.md', '.cursor/rules/speckit-radzen.mdc', 'SPECKIT-RADZEN.md', 'AGENTS.md', 'CLAUDE.md', '.github/copilot-instructions.md',
            '.speckit/radzen/local/README.md', '.speckit/radzen/VERSION') {
            Join-Path $repo $p | Should -Exist -Because $p
        }
        Join-Path $repo '.claude/speckit-radzen.hooks.json' | Should -Not -Exist
        Get-ChildItem $repo -Recurse -Force -Directory -Filter 'dot-*' | Should -BeNullOrEmpty
        $json = Get-Content (Join-Path $repo '.speckit/radzen/install-manifest.json') -Raw
        Test-Json -Json $json -SchemaFile (Join-Path (Get-KitRoot) 'core/schemas/install-manifest.schema.json') | Should -BeTrue
        (Read-Manifest $repo).files['.agents/skills/speckit-radzen/SKILL.md'].owner | Should -Be 'codex,generic'
        (Test-SpecKitRadzenInstall -Repository $repo).Healthy | Should -BeTrue
    }

    It 'the installed CLI works from the target repository' {
        $null = Install-SpecKitRadzen -Repository $repo -Agents generic -Yes
        $out = & pwsh -NoProfile -File (Join-Path $repo '.speckit/radzen/tools/speckit-radzen.ps1') version -Repository $repo
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '^2\.'
        $v = & pwsh -NoProfile -File (Join-Path $repo '.speckit/radzen/tools/speckit-radzen.ps1') verify-install -Repository $repo -Json | ConvertFrom-Json
        $v.Healthy | Should -BeTrue
    }

    It 'auto-detects agents from real signals, not from a bare .github folder' {
        New-Item -ItemType Directory (Join-Path $repo '.github/workflows') -Force | Out-Null
        (Install-SpecKitRadzen -Repository $repo -Yes -WhatIf).Agents | Should -Be @('generic')
        Set-Content (Join-Path $repo 'CLAUDE.md') '# Team rules'
        New-Item -ItemType Directory (Join-Path $repo '.cursor') | Out-Null
        Set-Content (Join-Path $repo '.github/copilot-instructions.md') '# Copilot'
        (Install-SpecKitRadzen -Repository $repo -Yes -WhatIf).Agents | Should -Be @('claude', 'copilot', 'cursor')
    }

    It 'merges managed blocks into existing instruction files and keeps user content' {
        Set-Content (Join-Path $repo 'AGENTS.md') "# House rules`n`nUse tabs."
        $null = Install-SpecKitRadzen -Repository $repo -Agents codex -Yes
        $text = Get-Content (Join-Path $repo 'AGENTS.md') -Raw
        $text | Should -Match '# House rules'
        $text | Should -Match 'speckit-radzen:begin 2\.'
        ([regex]::Matches($text, 'speckit-radzen:begin')).Count | Should -Be 1
        $null = Update-SpecKitRadzen -Repository $repo
        ([regex]::Matches((Get-Content (Join-Path $repo 'AGENTS.md') -Raw), 'speckit-radzen:begin')).Count | Should -Be 1
        (Get-Content (Join-Path $repo '.gitignore') -Raw) | Should -Match '\.speckit/radzen/tmp/'
    }

    It 'refuses to overwrite unmanaged files unless forced, and backs them up' {
        New-Item -ItemType Directory (Join-Path $repo '.cursor/rules') -Force | Out-Null
        Set-Content (Join-Path $repo '.cursor/rules/speckit-radzen.mdc') 'mine'
        { Install-SpecKitRadzen -Repository $repo -Agents cursor -Yes } | Should -Throw '*not managed*'
        Join-Path $repo '.speckit/radzen/core' | Should -Not -Exist
        $r = Install-SpecKitRadzen -Repository $repo -Agents cursor -Yes -Force
        $r.Summary | Should -Match 'backup'
        @(Get-ChildItem (Join-Path $repo '.speckit/radzen/backup') -Recurse -Force -Filter 'speckit-radzen.mdc').Count | Should -Be 1
    }

    It 'refuses a second install and supports WhatIf without changes' {
        $w = Install-SpecKitRadzen -Repository $repo -Agents generic -Yes -WhatIf
        $w.Applied | Should -BeFalse
        Join-Path $repo '.speckit' | Should -Not -Exist
        $null = Install-SpecKitRadzen -Repository $repo -Agents generic -Yes
        { Install-SpecKitRadzen -Repository $repo -Agents generic -Yes } | Should -Throw '*already installed*'
    }

    It 'rolls back completely when a write fails' {
        Set-Content (Join-Path $repo 'AGENTS.md') 'original'
        $before = @(Get-ChildItem $repo -Recurse -Force -File | Where-Object FullName -notmatch '[\\/]\.git[\\/]' | ForEach-Object FullName | Sort-Object)
        $env:SKR_INSTALL_FAIL_AFTER = '40'
        { Install-SpecKitRadzen -Repository $repo -Agents codex -Yes } | Should -Throw '*rolled back*'
        $env:SKR_INSTALL_FAIL_AFTER = $null
        $after = @(Get-ChildItem $repo -Recurse -Force -File | Where-Object FullName -notmatch '[\\/]\.git[\\/]' | ForEach-Object FullName | Sort-Object)
        $after | Should -Be $before
        Get-Content (Join-Path $repo 'AGENTS.md') -Raw | Should -Be "original`n"
        Join-Path $repo '.speckit' | Should -Not -Exist
    }

    It 'updates: replaces unmodified files, keeps local edits as .speckit-new, removes obsolete files' {
        $null = Install-SpecKitRadzen -Repository $repo -Agents claude -Yes
        $dist = New-DistCopy
        try {
            Set-Content (Join-Path $dist 'VERSION') '2.1.0'
            Add-Content (Join-Path $dist 'core/standards/testing.md') "`nNew guidance."
            Add-Content (Join-Path $dist 'core/standards/performance.md') "`nNew perf guidance."
            Remove-Item (Join-Path $dist 'core/standards/localization.md')
            Add-Content (Join-Path $repo '.speckit/radzen/core/standards/performance.md') "`nOur local tweak."
            $r = Update-SpecKitRadzen -Repository $repo -Source $dist
            $r.Version | Should -Be '2.1.0'
            Get-Content (Join-Path $repo '.speckit/radzen/core/standards/testing.md') -Raw | Should -Match 'New guidance'
            Get-Content (Join-Path $repo '.speckit/radzen/core/standards/performance.md') -Raw | Should -Match 'Our local tweak'
            Join-Path $repo '.speckit/radzen/core/standards/performance.md.speckit-new' | Should -Exist
            Join-Path $repo '.speckit/radzen/core/standards/localization.md' | Should -Not -Exist
            (Read-Manifest $repo).kitVersion | Should -Be '2.1.0'
            $t = Test-SpecKitRadzenInstall -Repository $repo
            $t.Healthy | Should -BeFalse
            ($t.Problems -join ' ') | Should -Match 'unmerged update'
        }
        finally { Remove-Item $dist -Recurse -Force }
    }

    It 'keeps .speckit/radzen/local untouched across update and uninstall' {
        $null = Install-SpecKitRadzen -Repository $repo -Agents generic -Yes
        Set-Content (Join-Path $repo '.speckit/radzen/local/constitution.local.md') '# local'
        $null = Update-SpecKitRadzen -Repository $repo -Force
        Get-Content (Join-Path $repo '.speckit/radzen/local/constitution.local.md') -Raw | Should -Be "# local`n"
        $null = Uninstall-SpecKitRadzen -Repository $repo
        Join-Path $repo '.speckit/radzen/local/constitution.local.md' | Should -Exist
    }

    It 'migrates a V1 install' {
        $v1 = Join-Path $repo '.speckit/radzen/core'
        New-Item -ItemType Directory (Join-Path $v1 'workflows') -Force | Out-Null
        Set-Content (Join-Path $v1 'workflows/discover.md') '# V1 discover'
        Set-Content (Join-Path $v1 'README.md') '# Spec Kit Radzen V1'
        New-Item -ItemType Directory (Join-Path $repo '.claude/commands') -Force | Out-Null
        Set-Content (Join-Path $repo '.claude/commands/speckit-radzen.plan.md') 'V1 command'
        { Install-SpecKitRadzen -Repository $repo -Agents claude -Yes } | Should -Throw '*not managed*'
        $r = Install-SpecKitRadzen -Repository $repo -Agents claude -Yes -Force
        $r.Summary | Should -Match 'migrated from V1'
        Join-Path $v1 'workflows/discover.md' | Should -Not -Exist
        Join-Path $v1 'workflows/01-discover.md' | Should -Exist
        Get-Content (Join-Path $repo '.claude/commands/speckit-radzen.plan.md') -Raw | Should -Match 'Generated by build/Build-Adapters.ps1'
        (Test-SpecKitRadzenInstall -Repository $repo).Healthy | Should -BeTrue
    }

    It 'adds MCP configuration without secrets and removes it on uninstall' {
        New-Item -ItemType Directory (Join-Path $repo '.vscode') | Out-Null
        Set-Content (Join-Path $repo '.vscode/mcp.json') '{ "servers": { "other": { "type": "http", "url": "https://example.invalid/mcp" } } }'
        $null = Install-SpecKitRadzen -Repository $repo -Agents claude, copilot, codex -McpClient ClaudeCode, VSCode, Codex -Yes
        $vs = Get-Content (Join-Path $repo '.vscode/mcp.json') -Raw | ConvertFrom-Json -AsHashtable
        $vs.servers.Keys | Should -Contain 'other'
        $vs.servers['radzen-blazor'].headers['X-Radzen-Key'] | Should -Be '${input:radzen-key}'
        (Test-SkrMcpConfiguration -Repository $repo -SkipUserLevel).Status | Should -Be 'configured'
        (Invoke-SkrAntiPatternScan -Repository $repo -All -NoWrite).findings | Where-Object rule -eq 'AP-SEC-05' | Should -BeNullOrEmpty
        $null = Uninstall-SpecKitRadzen -Repository $repo
        $vs = Get-Content (Join-Path $repo '.vscode/mcp.json') -Raw | ConvertFrom-Json -AsHashtable
        $vs.servers.Keys | Should -Be @('other')
        Join-Path $repo '.mcp.json' | Should -Not -Exist
        Join-Path $repo '.codex/config.toml' | Should -Not -Exist
    }

    It 'never replaces an existing user-authored Radzen MCP entry' {
        Set-Content (Join-Path $repo '.mcp.json') '{ "mcpServers": { "radzen-blazor": { "type": "http", "url": "https://app.radzen.com/mcp", "headers": { "X-Radzen-Key": "${MY_OWN_VAR}" } } } }'
        $null = Install-SpecKitRadzen -Repository $repo -Agents claude -McpClient ClaudeCode -Yes
        (Get-Content (Join-Path $repo '.mcp.json') -Raw) | Should -Match 'MY_OWN_VAR'
    }

    It 'merges and removes the Claude Code hook' {
        New-Item -ItemType Directory (Join-Path $repo '.claude') | Out-Null
        Set-Content (Join-Path $repo '.claude/settings.json') '{ "permissions": { "allow": ["Bash(dotnet build:*)"] } }'
        $null = Install-SpecKitRadzen -Repository $repo -Agents claude -EnableHooks -Yes
        $s = Get-Content (Join-Path $repo '.claude/settings.json') -Raw | ConvertFrom-Json
        $s.permissions.allow | Should -Contain 'Bash(dotnet build:*)'
        $s.hooks.PostToolUse[0].hooks[0].command | Should -Match 'speckit-radzen.ps1 scan'
        $null = Uninstall-SpecKitRadzen -Repository $repo
        $s = Get-Content (Join-Path $repo '.claude/settings.json') -Raw | ConvertFrom-Json
        $s.PSObject.Properties.Name | Should -Not -Contain 'hooks'
        $s.permissions.allow | Should -Contain 'Bash(dotnet build:*)'
    }

    It 'uninstall removes everything it added and leaves specs and user content' {
        Set-Content (Join-Path $repo 'AGENTS.md') '# Mine'
        $null = Install-SpecKitRadzen -Repository $repo -Agents claude, copilot, codex, cursor, generic -Yes
        $null = New-SkrFeature -Name 'Keep me' -Repository $repo
        Add-Content (Join-Path $repo '.claude/commands/speckit-radzen.plan.md') 'edited'
        $r = Uninstall-SpecKitRadzen -Repository $repo
        $r.Kept | Should -Be @('.claude/commands/speckit-radzen.plan.md')
        Join-Path $repo 'specs/001-keep-me/spec.md' | Should -Exist
        Get-Content (Join-Path $repo 'AGENTS.md') -Raw | Should -Be "# Mine`n"
        foreach ($p in '.speckit/radzen/core', '.speckit/radzen/tools', '.github', '.cursor', '.agents', 'SPECKIT-RADZEN.md', 'CLAUDE.md', '.speckit/radzen/install-manifest.json') {
            Join-Path $repo $p | Should -Not -Exist -Because $p
        }
    }
}

Describe 'Bootstrap wrappers' {
    BeforeEach { $repo = New-EmptyRepository -Git }
    AfterEach { Remove-TestRepository $repo }

    It 'PowerShell wrapper accepts the V1 -Agent parameter' {
        $out = & pwsh -NoProfile -File (Join-Path (Get-KitRoot) 'install/Install-SpecKitRadzen.ps1') -Repository $repo -Agent Codex -Yes
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'agents: codex'
        Join-Path $repo '.agents/skills/speckit-radzen/SKILL.md' | Should -Exist
    }

    It 'sh wrapper installs with list arguments' -Skip:($IsWindows) {
        $out = & /bin/sh (Join-Path (Get-KitRoot) 'install/install.sh') $repo --agents 'claude,cursor' --mcp-client 'ClaudeCode' --yes
        $LASTEXITCODE | Should -Be 0
        ($out -join "`n") | Should -Match 'agents: claude, cursor'
        Join-Path $repo '.mcp.json' | Should -Exist
        & /bin/sh (Join-Path (Get-KitRoot) 'install/install.sh') $repo --verify | Out-Null
        $LASTEXITCODE | Should -Be 0
    }
}
