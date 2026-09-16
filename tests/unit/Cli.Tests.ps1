BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'TestHelpers.psm1') -Force
    Import-KitModule
    $script:Cli = Join-Path (Get-KitRoot) 'tools/speckit-radzen.ps1'
    function Invoke-Cli { param([Parameter(ValueFromRemainingArguments)] $Rest) $out = & pwsh -NoProfile -File $script:Cli @Rest 2>&1; [pscustomobject]@{ Exit = $LASTEXITCODE; Text = (($out -join "`n") -replace '\x1b\[[0-9;]*[A-Za-z]', '') } }
}

Describe 'CLI' {
    BeforeAll { $repo = Copy-Fixture -Name 'webapp-interactive-server' -Git }
    AfterAll { Remove-TestRepository $repo }

    It 'prints help and version' {
        (Invoke-Cli help).Text | Should -Match 'Exit codes'
        (Invoke-Cli version).Text | Should -Match '^\d+\.\d+\.\d+'
    }
    It 'rejects unknown commands with exit code 3' { (Invoke-Cli frobnicate).Exit | Should -Be 3 }
    It 'detects and returns JSON' {
        $r = Invoke-Cli detect -Repository $repo -Json
        $r.Exit | Should -Be 0
        ($r.Text | ConvertFrom-Json).radzen.version.value | Should -Be '7.1.2'
    }
    It 'runs the feature flow with named, switch and positional arguments' {
        (Invoke-Cli new-feature Customer overview -Repository $repo).Text | Should -Match '001-customer-overview'
        (Invoke-Cli state -Feature 001 -McpAvailability available -Note "probe ok" -Repository $repo).Exit | Should -Be 0
        $g = Invoke-Cli gate G0 -Feature 001 -Repository $repo -Json
        $g.Exit | Should -Be 0
        ($g.Text | ConvertFrom-Json).status | Should -Be 'pass'
        (Invoke-Cli phase discover -Feature 001 -Repository $repo).Text | Should -Match 'Phase: discover'
        $lint = Invoke-Cli lint -Feature 001 -Artifact spec,plan -Repository $repo
        $lint.Exit | Should -Be 1
        $lint.Text | Should -Match 'placeholder'
        $ev = Invoke-Cli evidence add -Feature 001 -Component RadzenDataGrid -Members LoadData,Count -Question "paging?" -Query "RadzenDataGrid LoadData" -Source mcp -Summary "Use LoadData." -Repository $repo
        $ev.Text | Should -Match 'MCP-001'
        (Invoke-Cli evidence list -Feature 001 -Repository $repo).Text | Should -Match 'RadzenDataGrid'
        (Invoke-Cli state -All -Repository $repo).Text | Should -Match '001-customer-overview'
    }
    It 'scan exits 1 on blocker/major findings and lists manual rules' {
        Set-Content (Join-Path $repo 'src/Contoso.Crm.Web/Bad.razor') '@code { async void X() {} }'
        $s = Invoke-Cli scan -All -Repository $repo
        $s.Exit | Should -Be 1
        $s.Text | Should -Match 'AP-RND-04'
        (Invoke-Cli scan -ListManual -Repository $repo).Text | Should -Match 'AP-SEC-01'
        Remove-Item (Join-Path $repo 'src/Contoso.Crm.Web/Bad.razor')
    }
    It 'mcp-check reports status' { (Invoke-Cli mcp-check -SkipUserLevel -Repository $repo).Text | Should -Match 'MCP status: not-configured' }
    It 'status summarises the repository' { (Invoke-Cli status -Repository $repo).Text | Should -Match 'Spec Kit Radzen' }
    It 'install/verify/uninstall through the CLI' {
        $target = New-EmptyRepository -Git
        try {
            (Invoke-Cli install -Repository $target -Agents generic -Yes).Text | Should -Match 'Install Spec Kit Radzen'
            (Invoke-Cli verify-install -Repository $target).Exit | Should -Be 0
            (Invoke-Cli uninstall -Repository $target).Text | Should -Match 'Uninstall'
            (Invoke-Cli verify-install -Repository $target).Exit | Should -Be 1
        }
        finally { Remove-TestRepository $target }
    }
}
