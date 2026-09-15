# Parsers for feature artifacts.

function Read-SkrArtifactText {
    param([Parameter(Mandatory)][string] $FeaturePath, [Parameter(Mandatory)][string] $File)
    $p = Join-Path $FeaturePath $File
    if (-not (Test-Path $p)) { return $null }
    return (Get-Content $p -Raw)
}

function Get-SkrIdSet {
    param([AllowEmptyString()][AllowNull()][string] $Text, [Parameter(Mandatory)][string] $Prefix)
    if (-not $Text) { return @() }
    return @([regex]::Matches($Text, "\b$Prefix-[0-9]{3}\b") | ForEach-Object Value | Select-Object -Unique)
}

function Get-SkrSpecModel {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $raw = Read-SkrArtifactText -FeaturePath $FeaturePath -File 'spec.md'
    if ($null -eq $raw) { return $null }
    $text = Remove-SkrHtmlComment $raw
    $frSection = Get-SkrMarkdownSection -Markdown $text -Title 'Functional requirements'
    $acSection = Get-SkrMarkdownSection -Markdown $text -Title 'Acceptance criteria'
    $frs = @([regex]::Matches("$frSection", '\*\*(FR-[0-9]{3})\*\*') | ForEach-Object { $_.Groups[1].Value })
    $acs = foreach ($m in [regex]::Matches("$acSection", '\*\*(AC-[0-9]{3})\*\*\s*\(([^)]*)\)')) {
        [pscustomobject]@{ Id = $m.Groups[1].Value; Covers = @(Get-SkrIdSet -Text $m.Groups[2].Value -Prefix 'FR') }
    }
    $acsNoRef = @([regex]::Matches("$acSection", '\*\*(AC-[0-9]{3})\*\*(?!\s*\()') | ForEach-Object { $_.Groups[1].Value })
    [pscustomobject]@{
        Raw          = $raw
        Text         = $text
        FR           = $frs
        AC           = @($acs)
        ACWithoutRef = $acsNoRef
        NFR          = @(Get-SkrIdSet -Text (Get-SkrMarkdownSection -Markdown $text -Title 'Non-functional requirements') -Prefix 'NFR')
        Clarify      = @([regex]::Matches($text, '\[NEEDS CLARIFICATION[^\]]*\]') | ForEach-Object Value)
        AuthRows     = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $text -Title 'Authorization matrix'))
        StateRows    = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $text -Title 'UI states'))
        DataVolume   = Get-SkrMarkdownSection -Markdown $text -Title 'Data volume'
    }
}

function Get-SkrPlanModel {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $raw = Read-SkrArtifactText -FeaturePath $FeaturePath -File 'plan.md'
    if ($null -eq $raw) { return $null }
    $text = Remove-SkrHtmlComment $raw
    $slicesSection = Get-SkrMarkdownSection -Markdown $text -Title 'Vertical slices'
    $slices = foreach ($m in [regex]::Matches("$slicesSection", '(?ms)^###\s+(S-[0-9]{2})\b[^\n]*\n(.*?)(?=^###\s|\z)')) {
        $body = $m.Groups[2].Value
        [pscustomobject]@{
            Id           = $m.Groups[1].Value
            Covers       = @(Get-SkrIdSet -Text ([regex]::Match($body, '\*\*Covers:\*\*([^\n]*)').Groups[1].Value) -Prefix 'FR')
            Verification = [regex]::Match($body, '\*\*Verification:\*\*\s*([^\n]*)').Groups[1].Value.Trim()
            Stop         = [regex]::Match($body, '\*\*Stop conditions:\*\*\s*([^\n]*)').Groups[1].Value.Trim()
        }
    }
    [pscustomobject]@{
        Raw          = $raw
        Text         = $text
        Constitution = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $text -Title 'Constitution check'))
        Layers       = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $text -Title 'Layer impact'))
        McpRows      = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $text -Title 'Radzen MCP verification'))
        Components   = @(Get-SkrMarkdownTableRow (Get-SkrMarkdownSection -Markdown $text -Title 'Component strategy'))
        Dependencies = Get-SkrMarkdownSection -Markdown $text -Title 'Approved dependency changes'
        Slices       = @($slices)
        McpRefs      = @(Get-SkrIdSet -Text $text -Prefix 'MCP')
    }
}

function Get-SkrTaskModel {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $raw = Read-SkrArtifactText -FeaturePath $FeaturePath -File 'tasks.md'
    if ($null -eq $raw) { return $null }
    $text = Remove-SkrHtmlComment $raw
    $tasks = foreach ($m in [regex]::Matches($text, '(?ms)^- \[( |x|X)\] \*\*(T-[0-9]{3})\*\*([^\n]*)\n(.*?)(?=^- \[|^#|\z)')) {
        $body = $m.Groups[4].Value
        [pscustomobject]@{
            Id       = $m.Groups[2].Value
            Done     = $m.Groups[1].Value -ne ' '
            Parallel = $m.Groups[3].Value -match '\[P\]'
            Slice    = [regex]::Match($body, '\*\*Slice:\*\*\s*(S-[0-9]{2})').Groups[1].Value
            Covers   = @(Get-SkrIdSet -Text ([regex]::Match($body, '\*\*Covers:\*\*([^\n]*)').Groups[1].Value) -Prefix 'FR')
            CoversAC = @(Get-SkrIdSet -Text ([regex]::Match($body, '\*\*Covers:\*\*([^\n]*)').Groups[1].Value) -Prefix 'AC')
            Mcp      = @(Get-SkrIdSet -Text $body -Prefix 'MCP')
            Verify   = [regex]::Match($body, '\*\*Verification:\*\*\s*([^\n]*)').Groups[1].Value.Trim()
        }
    }
    [pscustomobject]@{ Raw = $raw; Text = $text; Tasks = @($tasks) }
}

function Get-SkrTestScenarioModel {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $raw = Read-SkrArtifactText -FeaturePath $FeaturePath -File 'test-scenarios.md'
    if ($null -eq $raw) { return $null }
    $text = Remove-SkrHtmlComment $raw
    $rows = @(Get-SkrMarkdownTableRow $text)
    $scenarios = foreach ($r in $rows) {
        if ($r['ID'] -match '^TS-[0-9]{3}$') { [pscustomobject]@{ Id = $r['ID']; Covers = @(Get-SkrIdSet -Text $r['Covers'] -Prefix 'AC'); Level = $r['Level'] } }
    }
    [pscustomobject]@{ Raw = $raw; Text = $text; Scenarios = @($scenarios) }
}

function Get-SkrEvidenceModel {
    param([Parameter(Mandatory)][string] $FeaturePath)
    $doc = Read-SkrJson -Path (Join-Path $FeaturePath 'mcp-evidence.json')
    if (-not $doc) { return @() }
    return @($doc.entries)
}

function New-SkrLintFinding {
    param(
        [Parameter(Mandatory)][string] $Artifact,
        [Parameter(Mandatory)][ValidateSet('error', 'warning')][string] $Severity,
        [Parameter(Mandatory)][string] $Rule,
        [Parameter(Mandatory)][string] $Message
    )
    [pscustomobject]@{ artifact = $Artifact; severity = $Severity; rule = $Rule; message = $Message }
}
