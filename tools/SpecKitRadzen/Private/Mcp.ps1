# MCP configuration helpers.

$script:SkrRadzenMcpUrl = 'https://app.radzen.com/mcp'
$script:SkrRadzenKeyHeader = 'X-Radzen-Key'
$script:SkrRadzenKeyEnv = 'RADZEN_MCP_KEY'

$script:SkrMcpClients = [ordered]@{
    ClaudeCode    = @{ File = '.mcp.json'; Template = 'claude-code.mcp.json'; RootKey = 'mcpServers'; Format = 'json' }
    VSCode        = @{ File = '.vscode/mcp.json'; Template = 'vscode.mcp.json'; RootKey = 'servers'; Format = 'json' }
    VisualStudio  = @{ File = '.vs/mcp.json'; Template = 'visual-studio.mcp.json'; RootKey = 'servers'; Format = 'json' }
    Cursor        = @{ File = '.cursor/mcp.json'; Template = 'cursor.mcp.json'; RootKey = 'mcpServers'; Format = 'json' }
    Codex         = @{ File = '.codex/config.toml'; Template = 'codex.config.toml'; RootKey = 'mcp_servers'; Format = 'toml' }
}

function Test-SkrSecretReference {
    <# True when a header value is a variable reference rather than a literal. #>
    [OutputType([bool])]
    param([AllowEmptyString()][string] $Value)
    return ($Value -match '^\s*\$\{[^}]+\}\s*$')
}

function Test-SkrPlaceholderValue {
    [OutputType([bool])]
    param([AllowEmptyString()][string] $Value)
    return ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '(?i)^(<.*>|your[-_ ].*|x{4,}|placeholder|changeme|\*+)$')
}

function Test-SkrPathIgnored {
    <# True when git ignores the path. Returns $false when git is unavailable (conservative: treat as tracked). #>
    [OutputType([bool])]
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $RelativePath)
    if (-not (Get-Command git -ErrorAction Ignore) -or -not (Test-Path (Join-Path $Repository '.git'))) { return $false }
    $tracked = & git -C $Repository ls-files --error-unmatch -- $RelativePath 2>$null
    if ($LASTEXITCODE -eq 0 -and $tracked) { return $false }
    & git -C $Repository check-ignore -q -- $RelativePath 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-SkrMcpServerEntry {
    <# Returns Radzen-related server entries from a client configuration file: name, url, key header value kind. #>
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][ValidateSet('json', 'toml')][string] $Format)
    $text = Get-Content -Path $Path -Raw
    if ($Format -eq 'json') {
        try { $doc = $text | ConvertFrom-Json -AsHashtable -Depth 32 }
        catch { return @([pscustomobject]@{ Name = '(unparseable)'; Url = $null; KeyKind = 'unknown'; Error = $_.Exception.Message; IsStudio = $false }) }
        foreach ($rootKey in 'mcpServers', 'servers') {
            if (-not $doc -or -not $doc.ContainsKey($rootKey) -or $doc[$rootKey] -isnot [hashtable]) { continue }
            foreach ($name in $doc[$rootKey].Keys) {
                $s = $doc[$rootKey][$name]
                if ($s -isnot [hashtable]) { continue }
                $url = [string]$s['url']
                $isRadzen = $url -match '(?i)radzen' -or $name -match '(?i)radzen'
                if (-not $isRadzen) { continue }
                $headers = if ($s['headers'] -is [hashtable]) { $s['headers'] } else { @{} }
                $keyName = @($headers.Keys | Where-Object { $_ -ieq $script:SkrRadzenKeyHeader }) | Select-Object -First 1
                $kind = 'absent'
                if ($keyName) {
                    $v = [string]$headers[$keyName]
                    $kind = if (Test-SkrSecretReference $v) { 'reference' } elseif (Test-SkrPlaceholderValue $v) { 'placeholder' } else { 'literal' }
                }
                foreach ($envKey in @(if ($s['env'] -is [hashtable]) { $s['env'].Keys })) {
                    $ev = [string]$s['env'][$envKey]
                    if ($envKey -match '(?i)radzen.*key' -and -not (Test-SkrSecretReference $ev) -and -not (Test-SkrPlaceholderValue $ev)) { $kind = 'literal' }
                }
                [pscustomobject]@{ Name = $name; Url = $url; KeyKind = $kind; Error = $null; IsStudio = ($name -match '(?i)studio' -or ($url -and $url -notmatch 'app\.radzen\.com')) }
            }
        }
    }
    else {
        foreach ($m in [regex]::Matches($text, '(?ms)^\[mcp_servers\.("?)([^\]"]+)\1\]\s*\n(.*?)(?=^\[(?!mcp_servers\.\2\.)|\z)')) {
            $name = $m.Groups[2].Value
            $body = $m.Groups[3].Value
            $url = [regex]::Match($body, '(?m)^\s*url\s*=\s*"([^"]*)"').Groups[1].Value
            if ($url -notmatch '(?i)radzen' -and $name -notmatch '(?i)radzen') { continue }
            $kind = 'absent'
            if ($body -match '(?ms)env_http_headers\s*=\s*\{[^}]*X-Radzen-Key' -or $body -match '(?ms)\[mcp_servers\.[^\]]+\.env_http_headers\][^\[]*X-Radzen-Key') { $kind = 'reference' }
            $literal = [regex]::Match($body, '(?ms)(?<!env_)http_headers\s*=\s*\{[^}]*"?X-Radzen-Key"?\s*=\s*"([^"]*)"')
            if (-not $literal.Success) { $literal = [regex]::Match($body, '(?ms)\[mcp_servers\.[^\]]+\.http_headers\][^\[]*"?X-Radzen-Key"?\s*=\s*"([^"]*)"') }
            if ($literal.Success) { $kind = if (Test-SkrPlaceholderValue $literal.Groups[1].Value) { 'placeholder' } else { 'literal' } }
            [pscustomobject]@{ Name = $name; Url = $url; KeyKind = $kind; Error = $null; IsStudio = ($name -match '(?i)studio') }
        }
    }
}

function Invoke-SkrMcpProbe {
    <# Sends an MCP initialize request to the Radzen endpoint. Returns available/unauthorized/unreachable. Never logs the key. #>
    param([string] $Url = $script:SkrRadzenMcpUrl, [int] $TimeoutSec = 15)
    $key = [Environment]::GetEnvironmentVariable($script:SkrRadzenKeyEnv)
    if (-not $key) { return [pscustomobject]@{ Status = 'not-configured'; Detail = "Environment variable $($script:SkrRadzenKeyEnv) is not set." } }
    $body = @{
        jsonrpc = '2.0'; id = 1; method = 'initialize'
        params  = @{ protocolVersion = '2025-06-18'; capabilities = @{}; clientInfo = @{ name = 'speckit-radzen'; version = (Get-SkrKitVersion) } }
    } | ConvertTo-Json -Depth 5
    $headers = @{ $script:SkrRadzenKeyHeader = $key; Accept = 'application/json, text/event-stream' }
    try {
        $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $body -ContentType 'application/json' -Headers $headers -TimeoutSec $TimeoutSec -SkipHttpErrorCheck
        switch ([int]$resp.StatusCode) {
            { $_ -ge 200 -and $_ -lt 300 } { return [pscustomobject]@{ Status = 'available'; Detail = "HTTP $($resp.StatusCode)" } }
            { $_ -in 401, 403 } { return [pscustomobject]@{ Status = 'unauthorized'; Detail = "HTTP $($resp.StatusCode): key rejected" } }
            429 { return [pscustomobject]@{ Status = 'quota-exhausted'; Detail = 'HTTP 429' } }
            default { return [pscustomobject]@{ Status = 'unreachable'; Detail = "HTTP $($resp.StatusCode)" } }
        }
    }
    catch { return [pscustomobject]@{ Status = 'unreachable'; Detail = $_.Exception.Message } }
}

function Get-SkrEvidenceRank {
    [OutputType([int])]
    param([Parameter(Mandatory)][string] $Source)
    switch ($Source) { 'compiler' { 1 } 'project' { 2 } 'mcp' { 3 } 'docs' { 4 } 'model' { 5 } default { throw "Unknown source '$Source'." } }
}

function Write-SkrEvidenceMarkdown {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $doc = Read-SkrJson -Path (Join-Path $FeaturePath 'mcp-evidence.json')
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# MCP Evidence: $($doc.feature)")
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('Generated from `mcp-evidence.json` by `speckit-radzen evidence`. Do not edit by hand.')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('Rank: 1 compiler · 2 project usage · 3 Radzen MCP · 4 official docs · 5 model knowledge (never sufficient alone).')
    $null = $sb.AppendLine()
    $entries = @($doc.entries)
    if (-not $entries.Count) { $null = $sb.AppendLine('No evidence recorded yet.') }
    else {
        $rows = foreach ($e in $entries) {
            [pscustomobject]@{
                ID = $e.id; Component = $e.component; Members = ($e.members -join ', '); Source = $e.source; Rank = $e.rank
                Compiled = if ($e.compileVerified) { 'yes' } else { 'no' }; Status = $e.status
            }
        }
        $null = $sb.Append((ConvertTo-SkrMarkdownTable -Rows $rows -Columns 'ID', 'Component', 'Members', 'Source', 'Rank', 'Compiled', 'Status'))
        foreach ($e in $entries) {
            $null = $sb.AppendLine()
            $null = $sb.AppendLine("## $($e.id) — $($e.component)")
            $null = $sb.AppendLine()
            $null = $sb.AppendLine("- **Question:** $($e.question)")
            if ($e.query) { $null = $sb.AppendLine("- **Query:** ``$($e.query)``") }
            $null = $sb.AppendLine("- **Source:** $($e.source) (rank $($e.rank))$(if ($e.server) { " via $($e.server)/$($e.tool)" })")
            $null = $sb.AppendLine("- **Answer summary:** $($e.summary)")
            if ($e.radzenVersion) { $null = $sb.AppendLine("- **Radzen.Blazor version:** $($e.radzenVersion)") }
            if (@($e.projectEvidence).Count) { $null = $sb.AppendLine("- **Project evidence:** $(@($e.projectEvidence) -join ', ')") }
            if ($e.fallbackApproved) { $null = $sb.AppendLine("- **Approved fallback:** $($e.fallbackReason)") }
            if ($e.supersedes) { $null = $sb.AppendLine("- **Supersedes:** $($e.supersedes)") }
            $null = $sb.AppendLine("- **Recorded:** $($e.at)")
        }
    }
    Write-SkrText -Path (Join-Path $FeaturePath 'mcp-evidence.md') -Content $sb.ToString()
}
